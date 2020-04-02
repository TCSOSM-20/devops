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
Library   OperatingSystem
Library   String
Library   Collections
Library   Process
Library   SSHLibrary

Resource   %{ROBOT_DEVOPS_FOLDER}/lib/vnfd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nsd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ns_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/connectivity_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ssh_lib.robot

Variables   %{ROBOT_DEVOPS_FOLDER}/resources/hackfest_basic_ns_data.py

Suite Teardown   Run Keyword And Ignore Error   Test Cleanup


*** Variables ***
${ns_id}   ${EMPTY}
${username}   ubuntu
${password}   ${EMPTY}
${vnf_member_index}   1
${vnf_ip_addr}   ${EMPTY}
${ns_config}   {vld: [ {name: mgmtnet, vim-network-name: %{VIM_MGMT_NET}} ] }
# ${ns_config}   ${EMPTY}

*** Test Cases ***
Create Hackfest Basic VNF Descriptor
    [Tags]   hackfest_basic

    Create VNFD   '%{PACKAGES_FOLDER}/${vnfd_pkg}'


Create Hackfest Basic NS Descriptor
    [Tags]   hackfest_basic

    Create NSD   '%{PACKAGES_FOLDER}/${nsd_pkg}'

Network Service Instance Test
    [Tags]   hackfest_basic

    ${id}=   Create Network Service   ${nsd_name}   %{VIM_TARGET}   ${ns_name}   ${ns_config}   ${publickey}
    Set Suite Variable   ${ns_id}   ${id}


Get Vnf Ip Address
    [Tags]   hackfest_basic

    ${ip_addr}  Get Vnf Management Ip Address   ${ns_id}   ${vnf_member_index}
    log   ${ip_addr}
    Set Suite Variable   ${vnf_ip_addr}   ${ip_addr}

Test Ping
    [Tags]   hackfest_basic
    Test Connectivity  ${vnf_ip_addr}

Test SSH Access
    [Tags]   hackfest_basic
    Sleep   30s   Waiting ssh daemon to be up
    Test SSH Connection  ${vnf_ip_addr}  ${username}  ${password}  ${privatekey} 

Delete NS Instance Test
    [Tags]   hackfest_basic   cleanup

    Delete NS   ${ns_name}


Delete NS Descriptor Test
    [Tags]   hackfest_basic   cleanup

    Delete NSD   ${nsd_name}


Delete VNF Descriptor Test
    [Tags]   hackfest_basic   cleanup

    Delete VNFD   ${vnfd_name}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suit Cleanup: Deleting Descriptor, instance and vim

    Run Keyword If Test Failed  Delete NS   ${ns_name}

    Run Keyword If Test Failed  Delete NSD   ${nsd_name}

    Run Keyword If Test Failed  Delete VNFD   ${vnfd_name}


