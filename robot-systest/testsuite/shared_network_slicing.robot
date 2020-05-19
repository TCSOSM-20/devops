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

Resource   %{ROBOT_DEVOPS_FOLDER}/lib/vnfd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nsd_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nst_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/nsi_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ns_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/connectivity_lib.robot
Resource   %{ROBOT_DEVOPS_FOLDER}/lib/ssh_lib.robot

Variables   %{ROBOT_DEVOPS_FOLDER}/resources/shared_network_slicing_data.py

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

    [Tags]   shared_network_slicing   SLICING-02

    Create VNFD   '%{PACKAGES_FOLDER}/${vnfd1_pkg}'
    Create VNFD   '%{PACKAGES_FOLDER}/${vnfd2_pkg}'


Create Slice NS Descriptors
    [Documentation]   Onboards all the NSDs required for the test: nsd1_pkg and nsd2_pkg (in the variables file)

    [Tags]   shared_network_slicing   SLICING-02

    Create NSD   '%{PACKAGES_FOLDER}/${nsd1_pkg}'
    Create NSD   '%{PACKAGES_FOLDER}/${nsd2_pkg}'

Create Slice Templates
    [Documentation]   Onboards the Network Slice Templates: nst, nst2 (in the variables file)

    [Tags]   shared_network_slicing   SLICING-02

    Create NST   '%{PACKAGES_FOLDER}/${nst}'
    Create NST   '%{PACKAGES_FOLDER}/${nst2}'

Network Slice One Instance Test
    [Documentation]   Instantiates the first NST recently onboarded (nst_name) and sets the instantiation id as a suite variable (nsi_id)
    ...               The slice contains 3 NS (1 shared)

    [Tags]   shared_network_slicing   SLICING-02

    ${id}=   Create Network Slice	${nst_name}   %{VIM_TARGET}   ${slice_name}   ${nst_config}   ${publickey}
    Set Suite Variable   ${nsi_id}   ${id}


Network Slice Two Instance Test
     [Documentation]   Instantiates the second NST recently onboarded (nst2_name) and sets the instantiation id as a suite variable (nsi2_id)
    ...               The slice contains 2 NS (1 shared)

    [Tags]   shared_network_slicing   SLICING-02

    ${id}=   Create Network Slice	${nst2_name}   %{VIM_TARGET}   ${slice2_name}   ${nst_config}   ${publickey}
    Set Suite Variable   ${nsi2_id}   ${id}


First Network Slice Ns Count
    [Documentation]   Counts the NS in both slice instances and shoul be equal to 4

    [Tags]   shared_network_slicing   SLICING-02

    ${slice1_count}=   Get Slice Ns Count	${slice_name}
    ${slice2_count}=   Get Slice Ns Count	${slice2_name}
    ${together}=   Evaluate   ${slice1_count} + ${slice2_count}
    Should Be Equal As Integers   ${together}   4


Get Middle Vnf Management Ip
    [Documentation]   Obtains the management IP of the shared NS main (only) VNF and sets it as a suite variable (mgmt_vnf_ip)

    [Tags]   shared_network_slicing   SLICING-02

    ${middle_ns_id}=   Run and Return RC and Output   osm ns-list | grep ${middle_ns_name} | awk '{print $4}' 2>&1
    ${vnf_ip}   Get Vnf Management Ip Address   ${middle_ns_id}[1]   ${vnf_member_index}
    Set Suite Variable   ${mgmt_vnf_ip}   ${vnf_ip}


Get First Slice Vnf IPs
    [Documentation]   Obtains the list of IPs addresses in the first slice and sets the list as a suite variable (slice1_vnfs_ips)

    [Tags]   shared_network_slicing   SLICING-02

    # Get all the ns_id in the slice except the middle one
    @{ip_list}   Get Slice Vnf Ip Addresses   ${slice_name}
    Set Suite Variable   ${slice1_vnfs_ips}   ${ip_list}


Test Middle Ns Ping
    [Documentation]   Pings the slice middle vnf (mgmt_vnf_ip)

    [Tags]   shared_network_slicing   SLICING-02

    Sleep   60s   Waiting for the network to be up
    # Ping to the middle VNF
    Test Connectivity  ${mgmt_vnf_ip}


Test Middle Vnf SSH Access
    [Documentation]   SSH access to the slice middle vnf (mgmt_vnf_ip) with the credentials provided in the variables file

    [Tags]   shared_network_slicing   SLICING-02

    Sleep   30s   Waiting ssh daemon to be up
    Test SSH Connection  ${mgmt_vnf_ip}  ${username}  ${password}  ${privatekey}


Test First Slice Connectivity
    [Documentation]   SSH access to the slice middle vnf (mgmt_vnf_ip) with the credentials provided in the variables file
    ...                 and pings all the IP addresses in the list (slice1_vnfs_ips)

    [Tags]   shared_network_slicing   SLICING-02

    Ping Many   ${mgmt_vnf_ip}  ${username}  ${password}  ${privatekey}   @{slice1_vnfs_ips}


Stop Slice One Instance
    [Documentation]   Stops the slice instance (slice_name)

    [Tags]   shared_network_slicing   SLICING-02   cleanup

    Delete NSI   ${slice_name}


Second Network Slice Ns Count
    [Documentation]   Counts the NS in both slice instances and should be equal to 2
    
    [Tags]   shared_network_slicing   SLICING-02

    ${slice1_count}=   Get Slice Ns Count	${slice_name}
    ${slice2_count}=   Get Slice Ns Count	${slice2_name}
    ${together}=   Evaluate   ${slice1_count} + ${slice2_count}
    Should Be Equal As Integers   ${together}   2

Get Second Slice Vnf IPs
    [Documentation]   Obtains the list of IPs addresses in the second slice and sets the list as a suite variable (slice2_vnfs_ips)

    [Tags]   shared_network_slicing   SLICING-02

    # Get all the ns_id in the slice
    @{ip_list}   Get Slice Vnf Ip Addresses   ${slice2_name}
    Set Suite Variable   ${slice2_vnfs_ips}   ${ip_list}


Test Second Slice Connectivity
    [Documentation]   SSH access to the slice middle vnf (mgmt_vnf_ip) with the credentials provided in the variables file
    ...                 and pings all the IP addresses in the list (slice2_vnfs_ips)

    [Tags]   shared_network_slicing   SLICING-02

    Ping Many   ${mgmt_vnf_ip}  ${username}  ${password}  ${privatekey}   @{slice2_vnfs_ips}


Stop Slice Two Instance
    [Documentation]   Stops the slice instance (slice2_name)

    [Tags]   shared_network_slicing   SLICING-02   cleanup

    Delete NSI   ${slice2_name}


Delete Slice One Template
    [Documentation]   Deletes the NST (nst_name) from OSM

    [Tags]   shared_network_slicing   SLICING-02   cleanup

    Delete NST   ${nst_name}


Delete Slice Two Template
    [Documentation]   Deletes the NST (nst2_name) from OSM

    [Tags]   shared_network_slicing   SLICING-02   cleanup

    Delete NST   ${nst2_name}


Delete NS Descriptors
    [Documentation]   Deletes all the NSDs created for the test: nsd1_name, nsd2_name

    [Tags]   shared_network_slicing   SLICING-02   cleanup

    Delete NSD   ${nsd1_name}
    Delete NSD   ${nsd2_name}


Delete VNF Descriptors
    [Documentation]   Deletes all the VNFDs created for the test: vnfd1_name, vnfd2_name

    [Tags]   shared_network_slicing   SLICING-02   cleanup

    Delete VNFD   ${vnfd1_name}
    Delete VNFD   ${vnfd2_name}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suit Cleanup: Deleting Descriptors, instance and templates

    Run Keyword If Test Failed  Delete NST   ${nst_name}
    Run Keyword If Test Failed  Delete NST   ${nst2_name}

    Run Keyword If Test Failed  Delete NSD   ${nsd1_name}
    Run Keyword If Test Failed  Delete NSD   ${nsd2_name}

    Run Keyword If Test Failed  Delete VNFD   ${vnfd1_name}
    Run Keyword If Test Failed  Delete VNFD   ${vnfd2_name}



