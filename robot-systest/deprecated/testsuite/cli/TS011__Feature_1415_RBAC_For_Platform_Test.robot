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
# 1. Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com : 21-nov-2019
##

*** Settings ***
Documentation    Test RBAC for platform using CRUD operations over users, projects and roles
Library     OperatingSystem
Library     String
Library     Collections
Resource    ../../lib/cli/rbac_lib.robot

#Suite Setup    Configure NBI For RBAC
Suite Teardown  Run Keyword And Ignore Error    Test Cleanup


*** Variables ***
${success_return_code}    0
# Test data for Users Operations test
${user_id}    ${EMPTY}
&{update_field1}    --set-project=admin,system_admin,project_admin      #project,role1,role2...
&{update_field2}    --add-project-role=admin,project_user     #project,role1,role2...
&{update_field3}    --add-project-role=service,account_manager       #project,role1,role2...
@{update_user}    ${update_field1}    ${update_field2}    ${update_field3}
# Test data for Project Operations test
${project_id}    ${EMPTY}
# Test data for Role Operations test
${role_id}    ${EMPTY}
${role_to_add}    "vims: true"


*** Test Cases ***
Test User Operations
    [Documentation]  Test RBAC using CRUD operation over users
    [Tags]  rabc    rabc_users    comprehensive

    ${user-name}=     Generate Random String    8    [NUMBERS]
    ${user-name}=     Catenate  SEPARATOR=  user_  ${user-name}
    set global variable  ${user-name}
    ${user-password}=     Generate Random String    8    [NUMBERS]
    set global variable  ${user-password}
    ${user_id}=    Create User    ${user-name}    ${user-password}
    List User And Check For The Created User    ${user-name}
    Get User Info By Name    ${user-name}
    Get User Info By ID    ${user_id}
    Update User And Verify Info    ${user-name}    @{update_user}
    Login With User And Perform Operation    ${user-name}    ${user-password}    admin
    Delete User And Check    ${user-name}


Test Project Operatios
    [Documentation]  Test RBAC using CRUD operation over projects
    [Tags]  rabc    rabc_projects    comprehensive

    ${project-name}=     Generate Random String    8    [NUMBERS]
    ${project-name}=     Catenate  SEPARATOR=  project_  ${project-name}
    set global variable  ${project-name}
    ${project_id}=    Create Project    ${project-name}
    List Project And Verify    ${project-name}
    Get Project Info By Name    ${project-name}
    Get Project Info By ID    ${project_id}
    ${new-project-name}=     Generate Random String    8    [NUMBERS]
    ${new-project-name}=     Catenate  SEPARATOR=  project_  ${new-project-name}
    set global variable  ${new-project-name}
    Update Project Name And Verify    ${project-name}    ${new-project-name}
    Delete Project And Verify    ${new-project-name}


Test Role Operations
    [Documentation]  Test RBAC using CRUD operation over roles
    [Tags]  rabc    rabc_roles    comprehensive

    ${role-name}=     Generate Random String    8    [NUMBERS]
    ${role-name}=     Catenate  SEPARATOR=  project_  ${role-name}
    set global variable  ${role-name}
    ${role_id}=    Create Role    ${role-name}
    List Roles And Verify    ${role-name}
    Get Role Info By Name    ${role-name}
    Get Role Info By ID    ${role_id}
    Add Role And Verify    ${role-name}    ${role_to_add}
    Delete Role And Verify    ${role-name}


*** Keywords ***
Test Cleanup
    Delete User    ${user-name}
    Delete Project    ${project-name}
    Delete Project    ${new-project-name}
    Delete Role    ${role-name}