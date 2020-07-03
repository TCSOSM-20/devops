#!/usr/bin/env python3
#   Copyright 2020 Canonical Ltd.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

import sys
import logging

sys.path.append("lib")

from ops.charm import CharmBase
from ops.framework import StoredState, Object
from ops.main import main
from ops.model import (
    ActiveStatus,
    MaintenanceStatus,
    BlockedStatus,
    ModelError,
)

from glob import glob
from pathlib import Path
from string import Template

logger = logging.getLogger(__name__)


class NGUICharm(CharmBase):
    state = StoredState()

    def __init__(self, framework, key):
        super().__init__(framework, key)
        self.state.set_default(spec=None)
        self.state.set_default(nbi_host=None)
        self.state.set_default(nbi_port=None)

        # Observe Charm related events
        self.framework.observe(self.on.config_changed, self.on_config_changed)
        self.framework.observe(self.on.start, self.on_start)
        self.framework.observe(self.on.upgrade_charm, self.on_upgrade_charm)
        self.framework.observe(
            self.on.nbi_relation_changed, self.on_nbi_relation_changed
        )

        # SSL Certificate path
        self.ssl_folder = "/certs"
        self.ssl_crt = "{}/ssl_certificate.crt".format(self.ssl_folder)
        self.ssl_key = "{}/ssl_certificate.key".format(self.ssl_folder)

    def _apply_spec(self):
        # Only apply the spec if this unit is a leader.
        unit = self.model.unit
        if not unit.is_leader():
            unit.status = ActiveStatus("Ready")
            return
        if not self.state.nbi_host or not self.state.nbi_port:
            unit.status = MaintenanceStatus("Waiting for NBI")
            return
        unit.status = MaintenanceStatus("Applying new pod spec")

        new_spec = self.make_pod_spec()
        if new_spec == self.state.spec:
            unit.status = ActiveStatus("Ready")
            return
        self.framework.model.pod.set_spec(new_spec)
        self.state.spec = new_spec
        unit.status = ActiveStatus("Ready")

    def make_pod_spec(self):
        config = self.framework.model.config

        ports = [
            {"name": "port", "containerPort": config["port"], "protocol": "TCP",},
        ]

        kubernetes = {
            "readinessProbe": {
                "tcpSocket": {"port": config["port"]},
                "timeoutSeconds": 5,
                "periodSeconds": 5,
                "initialDelaySeconds": 10,
            },
            "livenessProbe": {
                "tcpSocket": {"port": config["port"]},
                "timeoutSeconds": 5,
                "initialDelaySeconds": 45,
            },
        }

        ssl_certificate = None
        ssl_certificate_key = None
        try:
            ssl_certificate = self.model.resources.fetch("ssl_certificate")
            ssl_certificate_key = self.model.resources.fetch("ssl_certificate_key")
        except ModelError as e:
            logger.info(e)

        config_spec = {
            "port": config["port"],
            "server_name": config["server_name"],
            "client_max_body_size": config["client_max_body_size"],
            "nbi_host": self.state.nbi_host or config["nbi_host"],
            "nbi_port": self.state.nbi_port or config["nbi_port"],
            "ssl_crt": "",
            "ssl_crt_key": "",
        }

        if ssl_certificate and ssl_certificate_key:
            config_spec["ssl_crt"] = "ssl_certificate {};".format(self.ssl_crt)
            config_spec["ssl_crt_key"] = "ssl_certificate_key {};".format(self.ssl_key)
            config_spec["port"] = "{} ssl".format(config_spec["port"])

        files = [
            {
                "name": "configuration",
                "mountPath": "/etc/nginx/sites-available/",
                "files": {
                    Path(filename)
                    .name: Template(Path(filename).read_text())
                    .substitute(config_spec)
                    for filename in glob("files/*")
                },
            }
        ]

        if ssl_certificate and ssl_certificate_key:
            files.append(
                {
                    "name": "ssl",
                    "mountPath": self.ssl_folder,
                    "files": {
                        Path(filename)
                        .name: Template(Path(filename).read_text())
                        .substitute(config_spec)
                        for filename in [ssl_certificate, ssl_certificate_key]
                    },
                }
            )
        logger.debug(files)
        spec = {
            "version": 2,
            "containers": [
                {
                    "name": self.framework.model.app.name,
                    "image": "{}".format(config["image"]),
                    "ports": ports,
                    "kubernetes": kubernetes,
                    "files": files,
                }
            ],
        }

        return spec

    def on_config_changed(self, event):
        """Handle changes in configuration"""
        self._apply_spec()

    def on_start(self, event):
        """Called when the charm is being installed"""
        self._apply_spec()

    def on_upgrade_charm(self, event):
        """Upgrade the charm."""
        unit = self.model.unit
        unit.status = MaintenanceStatus("Upgrading charm")
        self.on_start(event)

    def on_nbi_relation_changed(self, event):
        unit = self.model.unit
        if not unit.is_leader():
            return
        self.state.nbi_host = event.relation.data[event.unit].get("host")
        self.state.nbi_port = event.relation.data[event.unit].get("port")
        self._apply_spec()

    def resource_get(self, resource_name: str) -> Path:
        from pathlib import Path
        from subprocess import run

        result = run(["resource-get", resource_name], output=True, text=True)
        return Path(result.stdout.strip())


if __name__ == "__main__":
    main(NGUICharm)
