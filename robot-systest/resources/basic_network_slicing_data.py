#   Copyright 2020 Atos
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

from pathlib import Path

# Get ${HOME} from local machine
home = str(Path.home())
# NS and VNF descriptor package files
vnfd1_pkg = 'slice_basic_vnf'
vnfd2_pkg = 'slice_basic_middle_vnfd'
nsd1_pkg = 'slice_basic_ns'
nsd2_pkg = 'slice_basic_middle_nsd'
nst = 'slice_basic_nst/slice_basic_nst.yaml'
# Instance names
slice_name = 'slicebasic'
middle_ns_name = 'slicebasic.slice_basic_nsd_2'
# Descriptor names
nst_name = 'slice_basic_nst'
vnfd1_name = 'slice_basic_vnfd'
vnfd2_name = 'slice_basic_middle_vnfd'
nsd1_name = 'slice_basic_nsd'
nsd2_name = 'slice_basic_middle_nsd'
# SSH keys to be used
publickey = home + '/.ssh/id_rsa.pub'
privatekey = home + '/.ssh/id_rsa'

