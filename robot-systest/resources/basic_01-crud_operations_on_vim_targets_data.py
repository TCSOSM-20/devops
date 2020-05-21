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

import os
import yaml
from pathlib import Path

# Prometheus host and port
prometheus_host = os.environ.get("OSM_HOSTNAME")
prometheus_port = "9091"

# VIM Configuration
vim_account_type = "openstack"
vim_name_prefix = "basic_01_vim_test"
# Get credentias from Openstack Clouds file
os_cloud = os.environ.get("OS_CLOUD")
clouds_file_paths = ["./clouds.yaml", str(Path.home()) + "/.config/openstack/clouds.yaml", "/etc/openstack/clouds.yaml"]
for path in clouds_file_paths:
    clouds_file_path = Path(path)
    if clouds_file_path.exists(): break
if not clouds_file_path.exists(): raise Exception("Openstack clouds file not found")
with clouds_file_path.open() as clouds_file:
    clouds = yaml.safe_load(clouds_file)
    if not os_cloud in clouds["clouds"]: raise Exception("Openstack cloud '" + os_cloud + "' not found")
    cloud = clouds["clouds"][os_cloud]
    if not "username" in cloud["auth"]: raise Exception("Username not found in Openstack cloud '" + os_cloud + "'")
    vim_user = cloud["auth"]["username"]
    if not "password" in cloud["auth"]: raise Exception("Password not found in Openstack cloud '" + os_cloud + "'")
    vim_password = cloud["auth"]["password"]
    if not "auth_url" in cloud["auth"]: raise Exception("Auth url not found in Openstack cloud '" + os_cloud + "'")
    vim_auth_url = cloud["auth"]["auth_url"]
    if not "project_name" in cloud["auth"]: raise Exception("Project name not found in Openstack cloud '" + os_cloud + "'")
    vim_tenant = cloud["auth"]["project_name"]
    vim_user_domain_name = cloud["auth"]["user_domain_name"] if "user_domain_name" in cloud["auth"] else "Default"
    vim_project_domain_name = cloud["auth"]["project_domain_name"] if "project_domain_name" in cloud["auth"] else "Default"
# Extra config
vim_config = "'{project_domain_name: " + vim_project_domain_name + ", user_domain_name: " + vim_user_domain_name + ", vim_network_name: " + os.environ.get("VIM_MGMT_NET") + "}'"
