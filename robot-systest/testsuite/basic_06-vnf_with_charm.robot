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
Documentation     [BASIC-06] VNF with Charm.

Library   OperatingSystem
Library   SSHLibrary

Resource   %{ROBOT_DEVOPS_FOLDER}/lib/vnfd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nsd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ns_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ssh_lib.robot

Variables   %{ROBOT_DEVOPS_FOLDER}/resources/basic_06-vnf_with_charm_data.py

Suite Teardown   Run Keyword And Ignore Error   Test Cleanup


*** Variables ***
${username}   ubuntu
${password}   ${EMPTY}
${ns_config}   {vld: [ {name: mgmtnet, vim-network-name: %{VIM_MGMT_NET}} ] }
${action_name}   touch
${vnf_member_index_1}   1
${vnf_member_index_2}   2
${day_1_file_name}   /home/ubuntu/first-touch
${day_2_file_name_1}   /home/ubuntu/mytouch1
${day_2_file_name_2}   /home/ubuntu/mytouch2
${ns_timeout}   15min


*** Test Cases ***
Create Charm VNF Descriptor
    [Tags]  charm

    Create VNFD  '%{PACKAGES_FOLDER}/${vnfd_pkg}'


Create Charm NS Descriptor
    [Tags]  charm

    Create NSD  '%{PACKAGES_FOLDER}/${nsd_pkg}'


Instantiate Charm Network Service
    [Tags]  charm

    ${id}=  Create Network Service  ${nsd_name}  %{VIM_TARGET}  ${ns_name}  ${ns_config}  ${publickey}  ${ns_timeout}
    Set Suite Variable  ${ns_id}  ${id}


Get Management Ip Addresses
    [Tags]  charm

    ${ip_addr_1}  Get Vnf Management Ip Address  ${ns_id}  ${vnf_member_index_1}
    log  ${ip_addr_1}
    Set Suite Variable  ${vnf_1_ip_addr}  ${ip_addr_1}
    ${ip_addr_2}  Get Vnf Management Ip Address  ${ns_id}  ${vnf_member_index_2}
    log  ${ip_addr_2}
    Set Suite Variable  ${vnf_2_ip_addr}  ${ip_addr_2}


Test SSH Access
    [Tags]  charm

    Variable Should Exist  ${vnf_1_ip_addr}  msg=IP address of the management VNF '${vnf_member_index_1}' is not available
    Variable Should Exist  ${vnf_2_ip_addr}  msg=IP address of the management VNF '${vnf_member_index_2}' is not available
    Sleep  30s  Waiting ssh daemon to be up
    Test SSH Connection  ${vnf_1_ip_addr}  ${username}  ${password}  ${privatekey}
    Test SSH Connection  ${vnf_2_ip_addr}  ${username}  ${password}  ${privatekey}


Check Remote Files Created Via Day 1 Operations
    [Documentation]     The Charm VNF has a Day 1 operation that creates a file named ${day_1_file_name}.
    ...                 This test checks whether that files have been created or not.
    [Tags]  charm

    Check If remote File Exists  ${vnf_1_ip_addr}  ${username}  ${password}  ${privatekey}  ${day_1_file_name}
    Check If remote File Exists  ${vnf_2_ip_addr}  ${username}  ${password}  ${privatekey}  ${day_1_file_name}


Execute Day 2 Operations
    [Documentation]     Performs one Day 2 operation per VNF that creates a new file.
    [Tags]  charm

    Variable Should Exist  ${ns_id}  msg=Network service instance is not available
    ${ns_op_id_1}=  Execute NS Action  ${ns_name}  ${action_name}  ${vnf_member_index_1}  filename=${day_2_file_name_1}
    ${ns_op_id_2}=  Execute NS Action  ${ns_name}  ${action_name}  ${vnf_member_index_2}  filename=${day_2_file_name_2}


Check Remote Files Created Via Day 2 Operations
    [Documentation]     Check whether the files created in the previous test via Day 2 operations exist or not.
    [Tags]  charm

    Check If remote File Exists  ${vnf_1_ip_addr}  ${username}  ${password}  ${privatekey}  ${day_2_file_name_1}
    Check If remote File Exists  ${vnf_2_ip_addr}  ${username}  ${password}  ${privatekey}  ${day_2_file_name_2}


Delete NS Instance
    [Tags]  charm  cleanup

    Delete NS  ${ns_name}


Delete NS Descriptor
    [Tags]  charm  cleanup

    Delete NSD  ${nsd_name}


Delete VNF Descriptor
    [Tags]  charm  cleanup

    Delete VNFD  ${vnfd_name}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suite Cleanup: Deleting descriptors and NS instance

    Run Keyword If Test Failed  Delete NS  ${ns_name}

    Run Keyword If Test Failed  Delete NSD  ${nsd_name}

    Run Keyword If Test Failed  Delete VNFD  ${vnfd_name}

