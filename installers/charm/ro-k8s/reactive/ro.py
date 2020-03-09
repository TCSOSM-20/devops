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
from charms.layer.caas_base import pod_spec_set
from charms.reactive import endpoint_from_flag
from charms.reactive import when, when_not, hook
from charms.reactive.flags import set_flag, clear_flag
from charmhelpers.core.hookenv import log, metadata, config
from charms import layer
from charms.osm.k8s import get_service_ip


@hook("upgrade-charm")
@when("leadership.is_leader")
def upgrade():
    clear_flag("ro-k8s.configured")


@when("config.changed")
@when("leadership.is_leader")
def restart():
    clear_flag("ro-k8s.configured")


@when_not("mysql.available")
@when_not("ro-k8s.configured")
def waiting_for_mysql():
    layer.status.waiting("Waiting for mysql to be ready")


@when("mysql.available")
@when_not("ro-k8s.configured")
@when("leadership.is_leader")
def configure():
    layer.status.maintenance("Configuring ro container")
    try:
        mysql = endpoint_from_flag("mysql.available")

        spec = make_pod_spec(
            mysql.host(),
            mysql.port(),
            mysql.user(),
            mysql.password(),
            mysql.root_password(),
        )

        log("set pod spec:\n{}".format(spec))
        pod_spec_set(spec)
        layer.status.active("creating container")
        set_flag("ro-k8s.configured")
    except Exception as e:
        layer.status.blocked("k8s spec failed to deploy: {}".format(e))


@when("ro-k8s.configured")
def set_ro_active():
    layer.status.active("ready")


@when("ro-k8s.configured", "ro.joined")
def send_config():
    layer.status.maintenance("Sending RO configuration")
    try:
        ro = endpoint_from_flag("ro.joined")
        if ro:
            service_ip = get_service_ip("ro")
            if service_ip:
                ro.send_connection(
                    service_ip, get_ro_port(),
                )
                clear_flag("ro.joined")
    except Exception as e:
        log("Fail sending RO configuration: {}".format(e))


def make_pod_spec(
    mysql_host, mysql_port, mysql_user, mysql_password, mysql_root_password
):
    """Make pod specification for Kubernetes

    Args:
        mysql_name (str): RO DB name
        mysql_host (str): RO DB host
        mysql_port (int): RO DB port
        mysql_user (str): RO DB user
        mysql_password (str): RO DB password
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
    }
    data.update(cfg)

    return pod_spec_template % data


def get_ro_port():
    """Returns RO port"""
    cfg = config()
    return cfg.get("advertised-port")
