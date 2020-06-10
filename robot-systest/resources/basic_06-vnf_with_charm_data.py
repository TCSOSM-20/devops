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
vnfd_pkg = 'hackfest_proxycharm_vnf.tar.gz'
nsd_pkg = 'hackfest_proxycharm_ns.tar.gz'
# NS and VNF descriptor names
vnfd_name = 'hackfest_proxycharm-vnf'
nsd_name = 'hackfest_proxycharm-ns'
# NS instance name
ns_name = 'basic_06_charm_test'
# SSH keys to be used
publickey = home + '/.ssh/id_rsa.pub'
privatekey = home + '/.ssh/id_rsa'
