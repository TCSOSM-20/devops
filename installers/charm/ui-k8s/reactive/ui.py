# Copyright 2020 Canonical Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#     Unless required by applicable law or agreed to in writing, software
#     distributed under the License is distributed on an "AS IS" BASIS,
#     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#     See the License for the specific language governing permissions and
#     limitations under the License.
#
from charms.layer.caas_base import pod_spec_set
from charms.reactive import endpoint_from_flag
from charms.reactive import when, when_not, hook
from charms.reactive.flags import set_flag, clear_flag
from charmhelpers.core.hookenv import (
    log,
    metadata,
    config,
)
from charms import layer


@hook("upgrade-charm")
@when("leadership.is_leader")
def upgrade():
    clear_flag("ui-k8s.configured")


@when("config.changed")
@when("leadership.is_leader")
def restart():
    clear_flag("ui-k8s.configured")


@when_not("mysql.available")
@when_not("ui-k8s.configured")
def waiting_for_mysql():
    layer.status.waiting("Waiting for mysql to be available")


@when_not("nbi.ready")
@when_not("ui-k8s.configured")
def waiting_for_nbi():
    layer.status.waiting("Waiting for nbi to be available")


@when("mysql.available", "nbi.ready")
@when_not("ui-k8s.configured")
@when("leadership.is_leader")
def configure():

    layer.status.maintenance("Configuring ui container")
    try:
        mysql = endpoint_from_flag("mysql.available")
        nbi = endpoint_from_flag("nbi.ready")
        nbi_unit = nbi.nbis()[0]
        nbi_host = "{}".format(nbi_unit["host"])
        spec = make_pod_spec(
            mysql.host(),
            mysql.port(),
            mysql.user(),
            mysql.password(),
            mysql.root_password(),
            nbi_host,
        )
        log("set pod spec:\n{}".format(spec))
        pod_spec_set(spec)
        set_flag("ui-k8s.configured")
    except Exception as e:
        layer.status.blocked("k8s spec failed to deploy: {}".format(e))


@when("ui-k8s.configured")
def set_ui_active():
    layer.status.active("ready")


def make_pod_spec(
    mysql_host, mysql_port, mysql_user, mysql_password, mysql_root_password, nbi_host
):
    """Make pod specification for Kubernetes

    Args:
        mysql_name (str): UI DB name
        mysql_host (str): UI DB host
        mysql_port (int): UI DB port
        mysql_user (str): UI DB user
        mysql_password (str): UI DB password
        nbi_uri (str): NBI URI
    Returns:
        pod_spec: Pod specification for Kubernetes
    """

    with open("reactive/spec_template.yaml") as spec_file:
        pod_spec_template = spec_file.read()

    md = metadata()
    cfg = config()

    data = {
        "name": md.get("name"),
        "docker_image": cfg.get("image"),
        "mysql_host": mysql_host,
        "mysql_port": mysql_port,
        "mysql_user": mysql_user,
        "mysql_password": mysql_password,
        "mysql_root_password": mysql_root_password,
        "nbi_host": nbi_host,
    }
    data.update(cfg)

    return pod_spec_template % data


def get_ui_port():
    """Returns UI port"""
    cfg = config()
    return cfg.get("advertised-port")
