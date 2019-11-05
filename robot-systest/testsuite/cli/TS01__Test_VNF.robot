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
Documentation    Test Suite to test basic cirros VNF and NS using osm-client
Library     OperatingSystem
Library     String
Library     Collections
Resource    ../../lib/cli/vnfd_lib.robot
Resource    ../../lib/cli/nsd_lib.robot
Resource    ../../lib/cli/ns_lib.robot
Resource    ../../lib/cli/vim_account_lib.robot
Library     ../../lib/custom_lib.py
Variables   ../../resource/cli/test_vnf_data.py

Suite Teardown     Run Keyword And Ignore Error    Test Cleanup


*** Variables ***
@{vnfd_ids}
@{nsd_ids}
@{ns_ids}


*** Test Cases ***
Create VNF Descriptor Test
    [Tags]    sanity    smoke

    Build VNF Descriptor    ${vnfdPckgPath}
    ${vnfd_id}=    Create VNFD    '${CURDIR}${/}../../..${vnfdPckgPath}${vnfdPckg}'
    Append To List     ${vnfd_ids}       ${vnfd_id}


Create NS Descriptor Test
    [Tags]    sanity     smoke

    Build NS Descriptor    ${nsdPckgPath}
    ${nsd_id}=    Create NSD    '${CURDIR}${/}../../..${nsdPckgPath}${nsdPckg}'
    Append To List     ${nsd_ids}       ${nsd_id}


Network Service Instance Test
    [Documentation]  Launch and terminate network services
    [Tags]    sanity
    [Teardown]  Run Keyword And Ignore Error    Network Service Instance Cleanup

    :FOR    ${vim_name}    IN    @{vim}
    \    Launch Network Services and Return    ${vim_name}


Delete NS Descriptor Test
    [Tags]    sanity     smoke

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Delete NSD      ${nsd}


Delete VNF Descriptor Test
    [Tags]    sanity    smoke

    :FOR    ${vnfd}  IN   @{vnfd_ids}
    \   Delete VNFD     ${vnfd}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suit Cleanup: Forcefully delete NSD and VNFD

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Force Delete NSD      ${nsd}

    :FOR    ${vnfd}  IN   @{vnfd_ids}
    \   Force Delete VNFD     ${vnfd}


Network Service Instance Cleanup
    [Documentation]  Forcefully delete created network service instances and vim account

    :FOR    ${ns}  IN   @{ns_ids}
    \   Force Delete NS   ${ns}
