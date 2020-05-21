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
Documentation     [BASIC-07] Secure key management.

Library   OperatingSystem
Library   SSHLibrary

Resource   %{ROBOT_DEVOPS_FOLDER}/lib/vnfd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nsd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ns_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ssh_lib.robot

Variables   %{ROBOT_DEVOPS_FOLDER}/resources/basic_07-secure_key_management_data.py

Suite Teardown   Run Keyword And Ignore Error   Test Cleanup


*** Variables ***
${username}   ubuntu
${password}   osm4u
${ns_config}   {vld: [ {name: mgmtnet, vim-network-name: %{VIM_MGMT_NET}} ] }
${action_name}   touch
${vnf_member_index}   1
${day_1_file_name}   /home/ubuntu/first-touch
${day_2_file_name}   /home/ubuntu/mytouch1


*** Test Cases ***
Create Nopasswd Charm VNF Descriptor
    [Tags]  nopasswd

    Create VNFD  '%{PACKAGES_FOLDER}/${vnfd_pkg}'


Create Nopasswd Charm NS Descriptor
    [Tags]  nopasswd

    Create NSD  '%{PACKAGES_FOLDER}/${nsd_pkg}'


Instantiate Nopasswd Charm Network Service
    [Tags]  nopasswd

    ${id}=  Create Network Service  ${nsd_name}  %{VIM_TARGET}  ${ns_name}  ${ns_config}  ${EMPTY}
    Set Suite Variable  ${ns_id}  ${id}


Get Management Ip Addresses
    [Tags]  nopasswd

    ${ip_addr}  Get Vnf Management Ip Address  ${ns_id}  ${vnf_member_index}
    log  ${ip_addr}
    Set Suite Variable  ${vnf_ip_addr}  ${ip_addr}


Test SSH Access
    [Tags]  nopasswd

    Variable Should Exist  ${vnf_ip_addr}  msg=IP address of the management VNF is not available
    Sleep  30s  Waiting ssh daemon to be up
    Test SSH Connection  ${vnf_ip_addr}  ${username}  ${password}  ${EMPTY}


Check Remote Files Created Via Day 1 Operations
    [Documentation]     The Nopasswd VNF has a Day 1 operation that creates a file named ${day_1_file_name} and performs it without password.
    ...                 This test checks whether that files have been created or not.
    [Tags]  nopasswd

    Check If remote File Exists  ${vnf_ip_addr}  ${username}  ${password}  ${EMPTY}  ${day_1_file_name}


Execute Day 2 Operations
    [Documentation]     Performs one Day 2 operation that creates a new file, this action is executed without password too.
    [Tags]  nopasswd

    Variable Should Exist  ${ns_id}  msg=Network service instance is not available
    ${ns_op_id}=  Execute NS Action  ${ns_name}  ${action_name}  ${vnf_member_index}  filename=${day_2_file_name}


Check Remote Files Created Via Day 2 Operations
    [Documentation]     Check whether the file created in the previous test via Day 2 operation exists or not.
    [Tags]  nopasswd

    Check If remote File Exists  ${vnf_ip_addr}  ${username}  ${password}  ${EMPTY}  ${day_2_file_name}


Delete NS Instance
    [Tags]  nopasswd  cleanup

    Delete NS  ${ns_name}


Delete NS Descriptor
    [Tags]  nopasswd  cleanup

    Delete NSD  ${nsd_name}


Delete VNF Descriptor
    [Tags]  nopasswd  cleanup

    Delete VNFD  ${vnfd_name}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suite Cleanup: Deleting descriptors and NS instance

    Run Keyword If Test Failed  Delete NS  ${ns_name}

    Run Keyword If Test Failed  Delete NSD  ${nsd_name}

    Run Keyword If Test Failed  Delete VNFD  ${vnfd_name}

