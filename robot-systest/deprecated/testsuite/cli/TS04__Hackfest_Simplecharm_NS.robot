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
${vnfdftpPath}    https://osm-download.etsi.org/ftp/osm-6.0-six/7th-hackfest/packages/hackfest_simplecharm_vnf.tar.gz
${nsdftpPath}    https://osm-download.etsi.org/ftp/osm-6.0-six/7th-hackfest/packages/hackfest_simplecharm_ns.tar.gz


*** Test Cases ***
Create Hackfest Simple Charm VNF Descriptor
    [Tags]   hackfest_simplecharm    comprehensive

    #Build VNF Descriptor    ${vnfdPckgPath}
    #Workarround for charm build issue
    ${rc}   ${stdout}=      Run and Return RC and Output    wget -P '${CURDIR}${/}../../..${vnfdPckgPath}${/}build/' ${vnfdftpPath}
    ${vnfd_id}=    Create VNFD    '${CURDIR}${/}../../..${vnfdPckgPath}${vnfdPckg}'
    Append To List     ${vnfd_ids}       ${vnfd_id}


Create Hackfest Simple Charm NS Descriptor
    [Tags]   hackfest_simplecharm    comprehensive

    #Build NS Descriptor    ${nsdPckgPath}
    ${rc}   ${stdout}=      Run and Return RC and Output    wget -P '${CURDIR}${/}../../..${nsdPckgPath}${/}build/' ${nsdftpPath}
    ${nsd_id}=    Create NSD    '${CURDIR}${/}../../..${nsdPckgPath}${nsdPckg}'
    Append To List     ${nsd_ids}       ${nsd_id}


Network Service Instance Test
    [Documentation]  Launch and terminate network services
    [Tags]   hackfest_simplecharm    comprehensive

    :FOR    ${vim_name}    IN    @{vim}
    \    Launch Network Services and Return    ${vim_name}


Delete NS Instance Test
    [Tags]    comprehensive   hackfest_simplecharm

    :FOR    ${ns}  IN   @{ns_ids}
    \   Delete NS   ${ns}


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
    [Documentation]  Test Suit Cleanup: Deliting Descriptor, instance and vim

    :FOR    ${ns}  IN   @{ns_ids}
    \   Delete NS   ${ns}

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Delete NSD      ${nsd}

    :FOR    ${vnfd}  IN   @{vnfd_ids}
    \   Delete VNFD     ${vnfd}

#    :FOR    ${vim_id}  IN   @{vim}
#    \   Delete Vim Account    ${vim_id}
