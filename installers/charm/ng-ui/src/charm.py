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
import base64

sys.path.append("lib")

from ops.charm import CharmBase
from ops.framework import StoredState, Object
from ops.main import main
from ops.model import (
    ActiveStatus,
    MaintenanceStatus,
    BlockedStatus,
    ModelError,
    WaitingStatus,
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
        self.ssl_crt_name = "ssl_certificate.crt"
        self.ssl_key_name = "ssl_certificate.key"

    def _apply_spec(self):
        # Only apply the spec if this unit is a leader.
        unit = self.model.unit
        if not unit.is_leader():
            unit.status = ActiveStatus("ready")
            return
        if not self.state.nbi_host or not self.state.nbi_port:
            unit.status = WaitingStatus("Waiting for NBI")
            return
        unit.status = MaintenanceStatus("Applying new pod spec")

        new_spec = self.make_pod_spec()
        if new_spec == self.state.spec:
            unit.status = ActiveStatus("ready")
            return
        self.framework.model.pod.set_spec(new_spec)
        self.state.spec = new_spec
        unit.status = ActiveStatus("ready")

    def make_pod_spec(self):
        config = self.framework.model.config

        config_spec = {
            "http_port": config["port"],
            "https_port": config["https_port"],
            "server_name": config["server_name"],
            "client_max_body_size": config["client_max_body_size"],
            "nbi_host": self.state.nbi_host or config["nbi_host"],
            "nbi_port": self.state.nbi_port or config["nbi_port"],
            "ssl_crt": "",
            "ssl_crt_key": "",
        }

        ssl_certificate = None
        ssl_certificate_key = None
        ssl_enabled = False

        if "ssl_certificate" in config and "ssl_certificate_key" in config:
            # Get bytes of cert and key
            cert_b = base64.b64decode(config["ssl_certificate"])
            key_b = base64.b64decode(config["ssl_certificate_key"])
            # Decode key and cert
            ssl_certificate = cert_b.decode("utf-8")
            ssl_certificate_key = key_b.decode("utf-8")
            # Get paths
            cert_path = "{}/{}".format(self.ssl_folder, self.ssl_crt_name)
            key_path = "{}/{}".format(self.ssl_folder, self.ssl_key_name)

            config_spec["port"] = "{} ssl".format(config["https_port"])
            config_spec["ssl_crt"] = "ssl_certificate {};".format(cert_path)
            config_spec["ssl_crt_key"] = "ssl_certificate_key {};".format(key_path)
            ssl_enabled = True
        else:
            config_spec["ssl_crt"] = ""
            config_spec["ssl_crt_key"] = ""

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
        port = config["https_port"] if ssl_enabled else config["port"]
        ports = [
            {"name": "port", "containerPort": port, "protocol": "TCP", },
        ]

        kubernetes = {
            "readinessProbe": {
                "tcpSocket": {"port": port},
                "timeoutSeconds": 5,
                "periodSeconds": 5,
                "initialDelaySeconds": 10,
            },
            "livenessProbe": {
                "tcpSocket": {"port": port},
                "timeoutSeconds": 5,
                "initialDelaySeconds": 45,
            },
        }

        if ssl_certificate and ssl_certificate_key:
            files.append(
                {
                    "name": "ssl",
                    "mountPath": self.ssl_folder,
                    "files": {
                        self.ssl_crt_name: ssl_certificate,
                        self.ssl_key_name: ssl_certificate_key,
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


if __name__ == "__main__":
    main(NGUICharm)
