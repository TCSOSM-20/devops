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
Documentation    Test Suite to create hackfest epa ns
Library     OperatingSystem
Library     String
Library     Collections
Resource    ../../lib/cli/vnfd_lib.robot
Resource    ../../lib/cli/nsd_lib.robot
Resource    ../../lib/cli/ns_lib.robot
Resource    ../../lib/cli/vim_account_lib.robot
Library     ../../lib/custom_lib.py
Variables   ../../resource/cli/hackfest_epa_ns_data.py

Suite Teardown     Run Keyword And Ignore Error    Test Cleanup


*** Variables ***
@{vnfd_ids}
${nsd_id}
@{nsd_ids}
@{ns_ids}


*** Test Cases ***
Create Hackfest EPA VNF Descriptor
    [Tags]     hackfest_epa

    Build VNF Descriptor    ${vnfdPckgPath}
    ${vnfd_id}=    Create VNFD    '${CURDIR}${/}../../..${vnfdPckgPath}${vnfdPckg}'
    Append To List     ${vnfd_ids}       ${vnfd_id}


Create Hackfest EPA NS Descriptor
    [Tags]     hackfest_epa

    Build NS Descriptor    ${nsdPckgPath}
    ${nsd_id}=    Create NSD    '${CURDIR}${/}../../..${nsdPckgPath}${nsdPckg}'
    Append To List     ${nsd_ids}       ${nsd_id}


Network Service Instance Test
    [Documentation]  Launch and terminate network services
    [Tags]    hackfest_epa
    [Teardown]  Run Keyword And Ignore Error    Network Service Instance Cleanup

    :FOR    ${vim_name}    IN    @{vim}
    \    Launch Network Services and Return    ${vim_name}


Delete NS Descriptor Test
    [Tags]    hackfest_epa

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Delete NSD      ${nsd}


Delete VNF Descriptor Test
    [Tags]    hackfest_epa

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
