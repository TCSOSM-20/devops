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

*** Settings ***
Documentation     [BASIC-09] Manual VNF/VDU Scaling.

Library   OperatingSystem
Library   String
Library   Collections

Resource   %{ROBOT_DEVOPS_FOLDER}/lib/vnfd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nsd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ns_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ssh_lib.robot

Variables   %{ROBOT_DEVOPS_FOLDER}/resources/basic_09-manual_vdu_scaling_data.py

Suite Teardown   Run Keyword And Ignore Error   Test Cleanup


*** Variables ***
${ns_config}   {vld: [ {name: mgmtnet, vim-network-name: %{VIM_MGMT_NET}} ] }
${scaling_group}   vdu_autoscale
${vnf_member_index}  1


*** Test Cases ***
Create Scaling VNF Descriptor
    [Tags]  manual_scaling

    Create VNFD  '%{PACKAGES_FOLDER}/${vnfd_pkg}'


Create Scaling NS Descriptor
    [Tags]  manual_scaling

    Create NSD  '%{PACKAGES_FOLDER}/${nsd_pkg}'


Instantiate Scaling Network Service
    [Tags]  manual_scaling

    ${id}=  Create Network Service  ${nsd_name}  %{VIM_TARGET}  ${ns_name}  ${ns_config}  ${publickey}
    Set Suite Variable  ${ns_id}  ${id}


Get Vnf Id
    [Tags]  manual_scaling

    Variable Should Exist  ${ns_id}  msg=Network service instance is not available
    @{vnfr_list}=  Get Ns Vnfr Ids  ${ns_id}
    Log List  ${vnfr_list}
    Set Suite Variable  ${vnf_id}  ${vnfr_list}[0]


Get Vdus Before Scale Out
    [Documentation]     Get the number of VDU records before the manual scaling.
    [Tags]  manual_scaling

    @{vdur_list}=  Get Vnf Vdur Names  ${vnf_id}
    Log List  ${vdur_list}
    ${vdurs}=  Get Length  ${vdur_list}
    Set Suite Variable  ${initial_vdur_count}  ${vdurs}


Perform Manual Vdu Scale Out
    [Tags]  manual_scaling

    Variable Should Exist  ${ns_id}  msg=Network service instance is not available
    ${ns_op_id}=  Execute Manual VNF Scale  ${ns_name}  ${vnf_member_index}  ${scaling_group}  SCALE_OUT


Check Vdus After Scale Out
    [Documentation]     Check whether there is one more VDU after scaling or not.
    [Tags]  manual_scaling

    Variable Should Exist  ${ns_id}  msg=Network service instance is not available
    @{vdur_list}=  Get Vnf Vdur Names  ${vnf_id}
    Log List  ${vdur_list}
    ${vdurs}=  Get Length  ${vdur_list}
    Run Keyword Unless  ${vdurs} == ${initial_vdur_count} + 1  Fail  msg=There is no new VDU records in the VNF after Scale Out


Perform Manual Vdu Scale In
    [Tags]  manual_scaling

    Variable Should Exist  ${ns_id}  msg=Network service instance is not available
    ${ns_op_id}=  Execute Manual VNF Scale  ${ns_name}  ${vnf_member_index}  ${scaling_group}  SCALE_IN


Check Vdus After Scaling In
    [Documentation]     Check whether there is one less VDU after scaling or not.
    [Tags]  manual_scaling

    Variable Should Exist  ${ns_id}  msg=Network service instance is not available
    @{vdur_list}=  Get Vnf Vdur Names  ${vnf_id}
    Log List  ${vdur_list}
    ${vdurs}=  Get Length  ${vdur_list}
    Run Keyword Unless  ${vdurs} == ${initial_vdur_count}  Fail  msg=There is the same number of VDU records in the VNF after Scale In


Delete NS Instance
    [Tags]  manual_scaling  cleanup

    Delete NS  ${ns_name}


Delete NS Descriptor
    [Tags]  manual_scaling  cleanup

    Delete NSD  ${nsd_name}


Delete VNF Descriptor
    [Tags]  manual_scaling  cleanup

    Delete VNFD  ${vnfd_name}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suite Cleanup: Deleting descriptors and NS instance

    Run Keyword If Test Failed  Delete NS  ${ns_name}

    Run Keyword If Test Failed  Delete NSD  ${nsd_name}

    Run Keyword If Test Failed  Delete VNFD  ${vnfd_name}

