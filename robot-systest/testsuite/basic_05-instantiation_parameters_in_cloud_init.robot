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
Documentation     [BASIC-05] Instantiation parameters in cloud-init.

Library   OperatingSystem
Library   SSHLibrary

Resource   %{ROBOT_DEVOPS_FOLDER}/lib/vnfd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nsd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ns_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ssh_lib.robot

Variables   %{ROBOT_DEVOPS_FOLDER}/resources/basic_05-instantiation_parameters_in_cloud_init_data.py

Suite Teardown   Run Keyword And Ignore Error   Test Cleanup


*** Variables ***
${username}   ubuntu
${new_password}   newpassword
${vnf_member_index}   1
${ns_config}   {vld: [ {name: mgmtnet, vim-network-name: %{VIM_MGMT_NET}} ], additionalParamsForVnf: [ { member-vnf-index: "${vnf_member_index}", additionalParams: { password: "${new_password}" } } ] }


*** Test Cases ***
Create Cloudinit VNF Descriptor
    [Tags]  instantiation_params

    Create VNFD  '%{PACKAGES_FOLDER}/${vnfd_pkg}'


Create Cloudinit NS Descriptor
    [Tags]  instantiation_params

    Create NSD  '%{PACKAGES_FOLDER}/${nsd_pkg}'


Instantiate Cloudinit Network Service Using Instantiation Parameters
    [Documentation]     Instantiates the NS using the instantiation parameter 'additionalParamsForVnf' to change the password of the default user.
    [Tags]  instantiation_params

    ${id}=  Create Network Service  ${nsd_name}  %{VIM_TARGET}  ${ns_name}  ${ns_config}  ${EMPTY}
    Set Suite Variable  ${ns_id}  ${id}


Get Management Ip Addresses
    [Tags]  instantiation_params

    ${ip_addr}  Get Vnf Management Ip Address  ${ns_id}  ${vnf_member_index}
    log  ${ip_addr}
    Set Suite Variable  ${vnf_ip_addr}  ${ip_addr}


Test SSH Access With The New Password
    [Documentation]     Test SSH access with the new password configured via cloud-init.
    [Tags]  instantiation_params

    Variable Should Exist  ${vnf_ip_addr}  msg=IP address of the management VNF is not available
    Sleep  30s  Waiting ssh daemon to be up
    Test SSH Connection  ${vnf_ip_addr}  ${username}  ${new_password}  ${EMPTY}


Delete NS Instance
    [Tags]  instantiation_params  cleanup

    Delete NS  ${ns_name}


Delete NS Descriptor
    [Tags]  instantiation_params  cleanup

    Delete NSD  ${nsd_name}


Delete VNF Descriptor
    [Tags]  instantiation_params  cleanup

    Delete VNFD  ${vnfd_name}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suite Cleanup: Deleting descriptors and NS instance

    Run Keyword If Test Failed  Delete NS  ${ns_name}

    Run Keyword If Test Failed  Delete NSD  ${nsd_name}

    Run Keyword If Test Failed  Delete VNFD  ${vnfd_name}

