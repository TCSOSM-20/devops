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
# NS and VNF descriptor package files
vnfd_pkg = 'hackfest_basic_metrics_vnf.tar.gz'
nsd_pkg = 'hackfest_basic_metrics_ns.tar.gz'
# NS and VNF descriptor names
vnfd_name = 'hackfest_basic_metrics-vnf'
nsd_name = 'hackfest_basic-ns-metrics'
# NS instance name
ns_name = 'basic_09_manual_scaling_test'
# SSH keys to be used
publickey = home + '/.ssh/id_rsa.pub'
privatekey = home + '/.ssh/id_rsa'
