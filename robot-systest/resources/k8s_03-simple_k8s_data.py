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
# K8s cluster name
k8scluster_name = 'k8s-test'
k8scluster_version = 'v1'
# NS and VNF descriptor package files
vnfd_pkg = 'hackfest_simple_k8s_vnfd.tar.gz'
nsd_pkg = 'hackfest_simple_k8s_nsd.tar.gz'
# NS and VNF descriptor package files
vnfd_name = 'hackfest-simple-k8s-vnfd'
nsd_name = 'hackfest-simple-k8s-nsd'
# NS instance name
ns_name = 'simple-k8s'
# SSH keys to be used
publickey = home + '/.ssh/id_rsa.pub'
privatekey = home + '/.ssh/id_rsa'
