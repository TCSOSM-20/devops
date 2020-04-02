# All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
##

## Change log:
# 1. Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com : 18-Dec-2019
##

*** Keywords ***
Create OSM NS Package
    [Arguments]  ${pkg_name}
    ${ns_pkg}=    Catenate	SEPARATOR=_     ${pkg_name}      ns
    ${ns_yaml}=   Catenate	SEPARATOR=_     ${pkg_name}      nsd
    ${ns_yaml}=   Catenate	SEPARATOR=.     ${ns_yaml}      yaml
    ${nsd_path}=    Join Path    ${ns_pkg}    ${ns_yaml}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm package-create ns ${pkg_name}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    File Should Exist    ${nsd_path}
    log  ${stdout}


Create OSM VNF Package
    [Arguments]  ${pkg_name}
    ${vnf_pkg}=    Catenate    SEPARATOR=_     ${pkg_name}      vnf
    ${vnf_yaml}=   Catenate	   SEPARATOR=_     ${pkg_name}      vnfd
    ${vnf_yaml}=   Catenate	   SEPARATOR=.     ${vnf_yaml}      yaml
    ${vnfd_path}=    Join Path    ${vnf_pkg}    ${vnf_yaml}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm package-create vnf ${pkg_name}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    File Should Exist    ${vnfd_path}
    log  ${stdout}


Validate OSM NS Package
    [Arguments]  ${pkg_name}
    ${ns_pkg}=    Catenate	SEPARATOR=_     ${pkg_name}      ns
    ${rc}   ${stdout}=      Run and Return RC and Output    osm package-validate ${ns_pkg}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    Verify Package Validation Result    ${ns_pkg}
    log  ${stdout}


Validate OSM VNF Package
    [Arguments]  ${pkg_name}
    ${vnf_pkg}= 	Catenate	SEPARATOR=_     ${pkg_name}      vnf
    ${rc}   ${stdout}=      Run and Return RC and Output    osm package-validate ${vnf_pkg}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    Verify Package Validation Result    ${vnf_pkg}
    log  ${stdout}


Verify Package Validation Result
    [Arguments]  ${pkg}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm package-validate ${pkg} | awk 'NR==6{print $6}'
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    Should Not Contain    ${stdout}    ERROR
    log  ${stdout}


Build OSM VNF Package
    [Arguments]  ${pkg_name}
    ${vnf_pkg}= 	Catenate	SEPARATOR=_     ${pkg_name}      vnf
    ${vnf_pkg_tar}= 	Catenate	SEPARATOR=.     ${vnf_pkg}      tar    gz
    ${rc}   ${stdout}=      Run and Return RC and Output    osm package-build ${vnf_pkg}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    File Should Exist    ${vnf_pkg_tar}
    log  ${stdout}


Build OSM NS Package
    [Arguments]  ${pkg_name}
    ${ns_pkg}= 	  Catenate	  SEPARATOR=_     ${pkg_name}      ns
    ${ns_pkg_tar}= 	  Catenate	  SEPARATOR=.     ${ns_pkg}      tar    gz
    ${rc}   ${stdout}=      Run and Return RC and Output    osm package-build ${ns_pkg}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    File Should Exist    ${ns_pkg_tar}
    log  ${stdout}
