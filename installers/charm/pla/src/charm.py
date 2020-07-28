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
    WaitingStatus,
)

from glob import glob
from pathlib import Path
from string import Template

logger = logging.getLogger(__name__)


class PLACharm(CharmBase):
    state = StoredState()

    def __init__(self, framework, key):
        super().__init__(framework, key)
        self.state.set_default(spec=None)
        self.state.set_default(kafka_host=None)
        self.state.set_default(kafka_port=None)
        self.state.set_default(mongodb_uri=None)

        # Observe Charm related events
        self.framework.observe(self.on.config_changed, self.on_config_changed)
        self.framework.observe(self.on.start, self.on_start)
        self.framework.observe(self.on.upgrade_charm, self.on_upgrade_charm)

        # Relations
        self.framework.observe(
            self.on.kafka_relation_changed, self.on_kafka_relation_changed
        )
        self.framework.observe(
            self.on.mongo_relation_changed, self.on_mongo_relation_changed
        )

    def _apply_spec(self):
        # Only apply the spec if this unit is a leader.
        unit = self.model.unit
        if not unit.is_leader():
            unit.status = ActiveStatus("ready")
            return
        if not self.state.kafka_host or not self.state.kafka_port:
            unit.status = WaitingStatus("Waiting for Kafka")
            return
        if not self.state.mongodb_uri:
            unit.status = WaitingStatus("Waiting for MongoDB")
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

        ports = [
            {"name": "port", "containerPort": config["port"], "protocol": "TCP", },
        ]

        config_spec = {
            "OSMPLA_MESSAGE_DRIVER": "kafka",
            "OSMPLA_MESSAGE_HOST": self.state.kafka_host,
            "OSMPLA_MESSAGE_PORT": self.state.kafka_port,
            "OSMPLA_DATABASE_DRIVER": "mongo",
            "OSMPLA_DATABASE_URI": self.state.mongodb_uri,
            "OSMPLA_GLOBAL_LOG_LEVEL": config["log_level"],
            "OSMPLA_DATABASE_COMMONKEY": config["database_common_key"],
        }

        spec = {
            "version": 2,
            "containers": [
                {
                    "name": self.framework.model.app.name,
                    "image": config["image"],
                    "ports": ports,
                    "config": config_spec,
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

    def on_kafka_relation_changed(self, event):
        unit = self.model.unit
        if not unit.is_leader():
            return
        self.state.kafka_host = event.relation.data[event.unit].get("host")
        self.state.kafka_port = event.relation.data[event.unit].get("port")
        self._apply_spec()

    def on_mongo_relation_changed(self, event):
        unit = self.model.unit
        if not unit.is_leader():
            return
        self.state.mongodb_uri = event.relation.data[event.unit].get(
            "connection_string"
        )
        self._apply_spec()


if __name__ == "__main__":
    main(PLACharm)
