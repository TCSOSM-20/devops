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

*** Settings ***
Library   OperatingSystem
Library   String
Library   Collections
Library   Process
Library   SSHLibrary
Library   yaml

Resource   %{ROBOT_DEVOPS_FOLDER}/lib/vnfd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nsd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nst_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nsi_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ns_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/connectivity_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ssh_lib.robot

Variables   %{ROBOT_DEVOPS_FOLDER}/resources/basic_network_slicing_data.py

Suite Teardown   Run Keyword And Ignore Error   Test Cleanup


*** Variables ***

${ns_id}   ${EMPTY}
${username}   osm
${password}   osm4u
${vnf_member_index}   1
${vnf_ip_addr}   ${EMPTY}
${nst_config}   {netslice-vld: [ {name: slice_vld_mgmt, vim-network-name: %{VIM_MGMT_NET}} ] }


*** Test Cases ***

Create Slice VNF Descriptors
    [Documentation]   Onboards all the VNFDs required for the test: vnfd1_pkg and vnfd2_pkg (in the variables file)

    [Tags]   basic_network_slicing   SLICING-01

    Create VNFD   '%{PACKAGES_FOLDER}/${vnfd1_pkg}'
    Create VNFD   '%{PACKAGES_FOLDER}/${vnfd2_pkg}'


Create Slice NS Descriptors
    [Documentation]   Onboards all the NSDs required for the test: nsd1_pkg and nsd2_pkg (in the variables file)

    [Tags]   basic_network_slicing   SLICING-01

    Create NSD   '%{PACKAGES_FOLDER}/${nsd1_pkg}'
    Create NSD   '%{PACKAGES_FOLDER}/${nsd2_pkg}'

Create Slice Template
    [Documentation]   Onboards the Network Slice Template: nst (in the variables file)

    [Tags]   basic_network_slicing   SLICING-01

    Create NST   '%{PACKAGES_FOLDER}/${nst}'

Network Slice Instance Test
    [Documentation]   Instantiates the NST recently onboarded and sets the instantiation id as a suite variable (nsi_id)

    [Tags]   basic_network_slicing   SLICING-01

    ${id}=   Create Network Slice	${nst_name}   %{VIM_TARGET}   ${slice_name}   ${nst_config}   ${publickey}
    Set Suite Variable   ${nsi_id}   ${id}


Get Middle Vnf Management Ip
    [Documentation]   Obtains the management IP of the slice middle VNF (name in the reources file) and sets the ip as a suite variable (mgmt_vnf_ip)

    [Tags]   basic_network_slicing   SLICING-01

    ${middle_ns_id}=   Run and Return RC and Output   osm ns-list | grep ${middle_ns_name} | awk '{print $4}' 2>&1
    ${vnf_ip}   Get Vnf Management Ip Address   ${middle_ns_id}[1]   ${vnf_member_index}
    Set Suite Variable   ${mgmt_vnf_ip}   ${vnf_ip}


Get Slice Vnf Ip Addresses
    [Documentation]   Obtains the list of IPs addresses in the slice and sets the list as a suite variable (slice_vnfs_ips)

    [Tags]   basic_network_slicing   SLICING-01

    # Get all the ns_id in the slice except the middle one to avoid self ping
    @{slice_ns_list}  Get Slice Ns List Except One   ${slice_name}    ${middle_ns_name}
    log many   @{slice_ns_list}
    @{temp_list}=    Create List
    # For each ns_id in the list, get all the vnf_id and their IP addresses
    FOR   ${ns_id}   IN   @{slice_ns_list}
        log   ${ns_id}
        @{vnf_id_list}   Get Ns Vnf List   ${ns_id}
        # For each vnf_id in the list, get all its IP addresses
        @{ns_ip_list}   Get Ns Ip List   @{vnf_id_list}
        @{temp_list}=   Combine Lists   ${temp_list}    ${ns_ip_list}
    END
    Log List   ${temp_list}
    Set Suite Variable   ${slice_vnfs_ips}   ${temp_list}


Test Middle Ns Ping
    [Documentation]   Pings the slice middle vnf (mgmt_vnf_ip)

    [Tags]   basic_network_slicing   SLICING-01
    Sleep   60s   Waiting for the network to be up
    # Ping to the middle VNF
    Test Connectivity  ${mgmt_vnf_ip}


Test Middle Vnf SSH Access
    [Documentation]   SSH access to the slice middle vnf (mgmt_vnf_ip) with the credentials provided in the variables file

    [Tags]   basic_network_slicing   SLICING-01
    Sleep   30s   Waiting ssh daemon to be up
    Test SSH Connection  ${mgmt_vnf_ip}  ${username}  ${password}  ${privatekey} 


Test Slice Connectivity
    [Documentation]   SSH access to the slice middle vnf (mgmt_vnf_ip) with the credentials provided in the variables file
    ...                 and pings all the IP addresses in the list (slice_vnfs_ips)

    [Tags]   basic_network_slicing   SLICING-01
    Ping Many   ${mgmt_vnf_ip}  ${username}  ${password}  ${privatekey}   @{slice_vnfs_ips}


Stop Slice Instance
    [Documentation]   Stops the slice instance (slice_name)

    [Tags]   basic_network_slicing   SLICING-01   cleanup

    Delete NSI   ${slice_name}


Delete Slice Template
    [Documentation]   Deletes the NST (nst_name) from OSM

    [Tags]   basic_network_slicing   SLICING-01   cleanup

    Delete NST   ${nst_name}


Delete NS Descriptors
    [Documentation]   Deletes all the NSDs created for the test: nsd1_name, nsd2_name

    [Tags]   basic_network_slicing   SLICING-01   cleanup

    Delete NSD   ${nsd1_name}
    Delete NSD   ${nsd2_name}


Delete VNF Descriptors
    [Documentation]   Deletes all the VNFDs created for the test: vnfd1_name, vnfd2_name

    [Tags]   basic_network_slicing   SLICING-01   cleanup

    Delete VNFD   ${vnfd1_name}
    Delete VNFD   ${vnfd2_name}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suit Cleanup: Deleting Descriptors, instance and template

    Run Keyword If Test Failed  Delete NST   ${nst_name}

    Run Keyword If Test Failed  Delete NSD   ${nsd1_name}
    Run Keyword If Test Failed  Delete NSD   ${nsd2_name}

    Run Keyword If Test Failed  Delete VNFD   ${vnfd1_name}
    Run Keyword If Test Failed  Delete VNFD   ${vnfd2_name}



