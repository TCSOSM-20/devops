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

from pathlib import Path

# Get ${HOME} from local machine
home = str(Path.home())
# NS and VNF descriptor package folder
vnfd_pkg = 'ubuntu_cloudinit_vnf'
nsd_pkg = 'ubuntu_cloudinit_ns'
# NS and VNF descriptor id
vnfd_name = 'ubuntu_cloudinit-vnf'
nsd_name = 'ubuntu_cloudinit-ns'
# NS instance name
ns_name = 'basic_05_instantiation_params_cloud_init'
