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

        # Observe Charm related events
        self.framework.observe(self.on.config_changed, self.on_config_changed)
        self.framework.observe(self.on.start, self.on_start)
        self.framework.observe(self.on.upgrade_charm, self.on_upgrade_charm)
        # self.framework.observe(
        #     self.on.nbi_relation_joined, self.on_nbi_relation_joined
        # )

    def _apply_spec(self):
        # Only apply the spec if this unit is a leader.
        if not self.framework.model.unit.is_leader():
            return
        new_spec = self.make_pod_spec()
        if new_spec == self.state.spec:
            return
        self.framework.model.pod.set_spec(new_spec)
        self.state.spec = new_spec

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
        config_spec = {
            "port": config["port"],
            "server_name": config["server_name"],
            "client_max_body_size": config["client_max_body_size"],
            "nbi_hostname": config["nbi_hostname"],
            "nbi_port": config["nbi_port"],
        }

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
            },
        ]
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
        unit = self.model.unit
        unit.status = MaintenanceStatus("Applying new pod spec")
        self._apply_spec()
        unit.status = ActiveStatus("Ready")

    def on_start(self, event):
        """Called when the charm is being installed"""
        unit = self.model.unit
        unit.status = MaintenanceStatus("Applying pod spec")
        self._apply_spec()
        unit.status = ActiveStatus("Ready")

    def on_upgrade_charm(self, event):
        """Upgrade the charm."""
        unit = self.model.unit
        unit.status = MaintenanceStatus("Upgrading charm")
        self.on_start(event)

    # def on_nbi_relation_joined(self, event):
    #     unit = self.model.unit
    #     if not unit.is_leader():
    #         return
    #     config = self.framework.model.config
    #     unit = MaintenanceStatus("Sending connection data")

    #     unit = ActiveStatus("Ready")


if __name__ == "__main__":
    main(NGUICharm)
