# -*- coding: utf-8 -*-

##
# Copyright 2019 Tech Mahindra Limited
#
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
# 1. Feature 7829: Mrityunjay Yadav, Jayant Madavi : MY00514913@techmahindra.com : 06-aug-2019
##


*** Settings ***
Documentation    Test Suite to create hackfest simplecharm ns
Library     OperatingSystem
Library     String
Library     Collections
Resource    ../../lib/cli/vnfd_lib.robot
Resource    ../../lib/cli/nsd_lib.robot
Resource    ../../lib/cli/ns_lib.robot
Resource    ../../lib/cli/vim_account_lib.robot
Library     ../../lib/custom_lib.py
Variables   ../../resource/cli/hackfest_simplecharm_ns_data.py

Suite Teardown     Run Keyword And Ignore Error    Test Cleanup


*** Variables ***
@{vnfd_ids}
${nsd_id}
@{nsd_ids}
@{ns_ids}
@{vim}
${vnfdftpPath}    https://osm-download.etsi.org/ftp/osm-6.0-six/7th-hackfest/packages/hackfest_simplecharm_vnf.tar.gz
${nsdftpPath}    https://osm-download.etsi.org/ftp/osm-6.0-six/7th-hackfest/packages/hackfest_simplecharm_ns.tar.gz


*** Test Cases ***
Create Hackfest Simple Charm VNF Descriptor
    [Tags]   hackfest_simplecharm    comprehensive

    #Build VNF Descriptor    ${vnfdPckgPath}
    #Workarround for charm build issue
    ${rc}   ${stdout}=      Run and Return RC and Output	    wget -P '${CURDIR}${/}../../..${vnfdPckgPath}${/}build/' ${vnfdftpPath}
    ${vnfd_id}=    Create VNFD    '${CURDIR}${/}../../..${vnfdPckgPath}${vnfdPckg}'
    Append To List     ${vnfd_ids}       ${vnfd_id}


Create Hackfest Simple Charm NS Descriptor
    [Tags]   hackfest_simplecharm    comprehensive

    #Build NS Descriptor    ${nsdPckgPath}
	${rc}   ${stdout}=      Run and Return RC and Output	    wget -P '${CURDIR}${/}../../..${nsdPckgPath}${/}build/' ${nsdftpPath}
    ${nsd_id}=    Create NSD    '${CURDIR}${/}../../..${nsdPckgPath}${nsdPckg}'
    Append To List     ${nsd_ids}       ${nsd_id}


Network Service Instance Test
    [Documentation]  Launch and terminate network services
    [Tags]   hackfest_simplecharm    comprehensive
    [Setup]  VIM Setup To Launch Network Services
    [Teardown]  Run Keyword And Ignore Error    Network Service Instance Cleanup

    Should Not Be Empty    ${vim}    VIM details not provided
    :FOR    ${vim_name}    IN    @{vim}
    \    Launch Network Services and Return    ${vim_name}


Delete NS Descriptor Test
    [Tags]   hackfest_simplecharm    comprehensive

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Delete NSD      ${nsd}


Delete VNF Descriptor Test
    [Tags]   hackfest_simplecharm    comprehensive

    :FOR    ${vnfd_id}  IN   @{vnfd_ids}
    \   Delete VNFD     ${vnfd_id}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suit Cleanup: Forcefully delete NSD and VNFD

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Force Delete NSD      ${nsd_id}

    :FOR    ${vnfd_id}  IN   @{vnfd_ids}
    \   Force Delete VNFD     ${vnfd_id}


Network Service Instance Cleanup
    [Documentation]  Forcefully delete created network service instances and vim account

    :FOR    ${ns_id}  IN   @{ns_ids}
    \   Force Delete NS   ${ns_id}

    :FOR    ${vim_id}  IN   @{vim}
    \   Force Delete Vim Account    ${vim_id}
