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
# 1. Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com : 18-Dec-2019
##

*** Settings ***
Library     OperatingSystem
Library     String
Library     Collections
Resource    ../../lib/cli/vnfd_lib.robot
Resource    ../../lib/cli/nsd_lib.robot
Resource    ../../lib/cli/ns_lib.robot
Resource    ../../lib/cli/vim_account_lib.robot
Library     ../../lib/custom_lib.py

Suite Setup    Prerequisite For Test
Suite Teardown  Run Keyword And Ignore Error    Test Cleanup


*** Variables ***
${success_return_code}    0

@{vim}
@{vnfd_ids}
${nsd_id}
@{nsd_ids}
@{ns_ids}
${vnfdPckg}    hackfest_basic_vnf.tar.gz
${nsdPckg}    hackfest_basic_ns.tar.gz
${vnfdftpPath}    https://osm-download.etsi.org/ftp/osm-5.0-five/6th-hackfest/packages/hackfest_basic_vnf.tar.gz
${nsdftpPath}    https://osm-download.etsi.org/ftp/osm-5.0-five/6th-hackfest/packages/hackfest_basic_ns.tar.gz


*** Test Cases ***
Create VNF Descriptor Test
    [Tags]  comprehensive    feature7921

    ${rc}   ${stdout}=      Run and Return RC and Output    wget -P '${CURDIR}${/}../../resource/' ${vnfdftpPath}
    ${vnfd_id}=    Create VNFD    '${CURDIR}${/}../../resource${/}${vnfdPckg}'
    Append To List     ${vnfd_ids}       ${vnfd_id}


Create NS Descriptor Test
    [Tags]  comprehensive    feature7921

    ${rc}   ${stdout}=      Run and Return RC and Output    wget -P '${CURDIR}${/}../../resource/' ${nsdftpPath}
    ${nsd_id}=    Create VNFD    '${CURDIR}${/}../../resource${/}${nsdPckg}'
    Append To List     ${nsd_ids}       ${nsd_id}


Instanciate Network Service Test
    [Tags]  comprehensive    feature7921
    [Setup]  Wait Until Keyword Succeeds    2x    30sec    VIM Setup To Launch Network Services

    :FOR    ${vim_name}    IN    @{vim}
    \    Launch Network Services and Return    ${vim_name}


Delete NS Instance Test
    [Tags]  comprehensive    feature7921

    :FOR    ${ns}  IN   @{ns_ids}
    \   Delete NS   ${ns}


Delete NS Descriptor Test
    [Tags]  comprehensive    feature7921

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Delete NSD      ${nsd}


Delete VNF Descriptor Test
    [Tags]  comprehensive    feature7921

    :FOR    ${vnfd_id}  IN   @{vnfd_ids}
    \   Delete VNFD     ${vnfd_id}


*** Keywords ***
Prerequisite For Test
    [Documentation]  Update docker service to use mongodb as file system

    Update NBI Service
    Update LCM Service


Update NBI Service
    ${rc}   ${stdout}=      Run and Return RC and Output    docker service update osm_nbi --force --env-add OSMNBI_STORAGE_DRIVER=mongo --env-add OSMNBI_STORAGE_PATH=/app/storage --env-add OSMNBI_STORAGE_COLLECTION=files --env-add OSMNBI_STORAGE_URI=mongodb://mongo:27017
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    Sleep    30s    Wait for NBI service to be update


Update LCM Service
    ${rc}   ${stdout}=      Run and Return RC and Output    docker service update osm_lcm --force --env-add OSMLCM_STORAGE_DRIVER=mongo --env-add OSMLCM_STORAGE_PATH=/app/storage --env-add OSMLCM_STORAGE_COLLECTION=files --env-add OSMLCM_STORAGE_URI=mongodb://mongo:27017
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    Sleep    30s    Wait for LCM service to be update


Test Cleanup
#    :FOR    ${vim_id}  IN   @{vim}
#    \   Delete Vim Account    ${vim_id}

    ${rc}   ${stdout}=      Run and Return RC and Output    docker service rollback osm_nbi
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    ${rc}   ${stdout}=      Run and Return RC and Output    docker service rollback osm_lcm
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
