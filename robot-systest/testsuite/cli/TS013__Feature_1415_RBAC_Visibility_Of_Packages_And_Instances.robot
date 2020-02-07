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
Documentation    Test RBAC for platform - Visibility of packages and instances test
Library     OperatingSystem
Library     String
Library     Collections
Resource    ../../lib/cli/rbac_lib.robot
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

# Test data for Users Operations test
${user_id}    ${EMPTY}

# Test data for Project Operations test
${project_id}    ${EMPTY}


*** Test Cases ***
Create VIM Account For New User
    [Documentation]  Test to create VIM account for newly created user
    [Tags]  rabc    rabc_vim    comprehensive    nbi

    Wait Until Keyword Succeeds    2x    30sec    VIM Setup To Launch Network Services


Create VNF Descriptor For New User
    [Documentation]  Test to create vnfd for new user
    [Tags]  rabc    rabc_vnfd    comprehensive    nbi

    ${rc}   ${stdout}=      Run and Return RC and Output    wget -P '${CURDIR}${/}../../resource/cli/rbac/' ${vnfdftpPath}
    ${vnfd_id}=    Create VNFD    '${CURDIR}${/}../../resource/cli/rbac${/}${vnfdPckg}'
    Append To List     ${vnfd_ids}       ${vnfd_id}


Create NS Descriptor For New User
    [Documentation]  Test to create nsd for new user
    [Tags]  rabc    rabc_nsd    comprehensive    nbi

    ${rc}   ${stdout}=      Run and Return RC and Output    wget -P '${CURDIR}${/}../../resource/cli/rbac/' ${nsdftpPath}
    ${nsd_id}=    Create VNFD    '${CURDIR}${/}../../resource/cli/rbac${/}${nsdPckg}'
    Append To List     ${nsd_ids}       ${nsd_id}


Instanciate Network Service For New User
    [Documentation]  Launch network services for new user
    [Tags]   rabc    rabc_ns    comprehensive    nbi

    :FOR    ${vim_name}    IN    @{vim}
    \    Launch Network Services and Return    ${vim_name}


Delete NS Instance Test
    [Tags]    rabc    rabc_ns    comprehensive    nbi

    :FOR    ${ns}  IN   @{ns_ids}
    \   Delete NS   ${ns}


Delete NS Descriptor Test
    [Tags]   rabc    rabc_nsd    comprehensive    nbi

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Delete NSD      ${nsd}


Delete VNF Descriptor Test
    [Tags]   rabc    rabc_vnfd    comprehensive    nbi

    :FOR    ${vnfd_id}  IN   @{vnfd_ids}
    \   Delete VNFD     ${vnfd_id}


*** Keywords ***
Prerequisite For Test
    ${user-name}=     Generate Random String    8    [NUMBERS]
    ${user-name}=     Catenate  SEPARATOR=  user_  ${user-name}
    set global variable  ${user-name}
    ${user-password}=     Generate Random String    8    [NUMBERS]
    set global variable  ${user-password}
    ${user_id}=    Create User    ${user-name}    ${user-password}

    ${project-name}=     Generate Random String    8    [NUMBERS]
    ${project-name}=     Catenate  SEPARATOR=  project_  ${project-name}
    set global variable  ${project-name}
    ${project_id}=    Create Project    ${project-name}

    &{update_field1}=    Create Dictionary    --add-project-role=admin,project_user
    &{update_field2}=    Create Dictionary    --add-project-role=${project-name},account_manager
    @{update_user}=    Create List    ${update_field1}    ${update_field2}
    Update User And Verify Info    ${user-name}    @{update_user}
    Login With User And Perform Operation    ${user-name}    ${user-password}    ${project-name}


Test Cleanup
    [Documentation]  Test Suit Cleanup: Deliting Descriptor, instance and vim

#    :FOR    ${vim_id}  IN   @{vim}
#    \   Delete Vim Account    ${vim_id}

    Logout and Login With Admin

    Delete User    ${user-name}
    Delete Project    ${project-name}
