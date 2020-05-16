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

*** Keywords ***
Configure NBI For RBAC
    ${rc}   ${stdout}=      Run and Return RC and Output    docker service update osm_nbi --force --env-add OSMNBI_AUTHENTICATION_BACKEND=keystone --env-add OSMNBI_AUTHENTICATION_AUTH_URL=keystone --env-add OSMNBI_AUTHENTICATION_AUTH_PORT=5000 --env-add OSMNBI_AUTHENTICATION_USER_DOMAIN_NAME=default --env-add OSMNBI_AUTHENTICATION_PROJECT_DOMAIN_NAME=default --env-add OSMNBI_AUTHENTICATION_SERVICE_USERNAME=nbi --env-add OSMNBI_AUTHENTICATION_SERVICE_PROJECT=service
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    Sleep    30s    Wait for NBI service to be update


Create User
    [Arguments]  ${user}    ${password}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm user-create ${user} --password ${password}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log     ${stdout}
    [Return]    ${stdout}


List User
    ${rc}   ${stdout}=      Run and Return RC and Output    osm user-list
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log     ${stdout}
    [Return]    ${stdout}


List User And Check For The Created User
    [Arguments]  ${user}
    ${user list}=    List User
    Should Contain    ${user list}    ${user}


Get User Info By Name
    [Arguments]  ${user_name}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm user-show ${user_name}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log     ${stdout}


Get User Info By ID
    [Arguments]  ${user_id}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm user-show ${user_id}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log     ${stdout}


Update User
    [Arguments]  ${user}    ${field}    ${value}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm user-update ${field} ${value} ${user}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log     ${stdout}


Update User And Verify Info
    [Arguments]    ${user}  @{args}
    FOR    ${arg}    IN    @{args}
        ${fields}=    Get Dictionary Items    ${arg}
        Update User    ${user}    ${fields[0]}    ${fields[1]}
    END
    ${rc}   ${stdout}=      Run and Return RC and Output    osm user-show ${user}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log     ${stdout}


Login With User And Perform Operation
    [Arguments]  ${user}    ${password}    ${project}
    ${rc}   ${stdout}=      Run and Return RC and Output    export OSM_USER=${user}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    ${rc}   ${stdout}=      Run and Return RC and Output    export OSM_PROJECT=${project}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    ${rc}   ${stdout}=      Run and Return RC and Output    export OSM_PASSWORD=${password}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-list
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log    ${stdout}
    Logout and Login With Admin


Logout and Login With Admin
    ${rc}   ${stdout}=      Run and Return RC and Output    export OSM_USER=admin
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    ${rc}   ${stdout}=      Run and Return RC and Output    export OSM_PASSWORD=admin
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-list
    Should Be Equal As Integers 	${rc}	  ${success_return_code}


Delete User
    [Arguments]  ${user}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm user-delete ${user}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}


Delete User And Check
    [Arguments]  ${user}
    Delete User    ${user}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm user-list
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    Should Not Contain      ${stdout}   ${user}


Create Project
    [Arguments]  ${project}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm project-create ${project}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log  ${stdout}
    [Return]  ${stdout}


List Project
    ${rc}   ${stdout}=      Run and Return RC and Output    osm project-list
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log  ${stdout}
    [Return]  ${stdout}


List Project And Verify
    [Arguments]  ${project}
    ${project list}=    List Project
    Should Contain    ${project list}    ${project}


Get Project Info By Name
    [Arguments]  ${project_name}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm project-show ${project_name}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log  ${stdout}
    [Return]  ${stdout}


Get Project Info By ID
    [Arguments]  ${project_id}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm project-show ${project_id}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log  ${stdout}
    [Return]  ${stdout}


Update Project
    [Arguments]  ${project}    ${feild}    ${value}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm project-update ${feild} ${value} ${project}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log  ${stdout}


Update Project Name And Verify
    [Arguments]  ${old_name}    ${new_name}
    Update Project    ${old_name}    --name    ${new_name}
    List Project And Verify    ${new_name}


Delete Project
    [Arguments]  ${project}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm project-delete ${project}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}


Delete Project And Verify
    [Arguments]  ${project}
    Delete Project    ${project}
    ${project_list}=    List Project
    Should Not Contain    ${project_list}    ${project}


Create Role
    [Arguments]  ${role}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm role-create ${role}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log  ${stdout}
    [Return]  ${stdout}


List Roles
    ${rc}   ${stdout}=      Run and Return RC and Output    osm role-list
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log  ${stdout}
    [Return]  ${stdout}


List Roles And Verify
    [Arguments]  ${role}
    ${role_list}=    List Roles
    Should Contain    ${role_list}    ${role}


Get Role Info By Name
    [Arguments]  ${role}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm role-show ${role}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log  ${stdout}
    [Return]  ${stdout}


Get Role Info By ID
    [Arguments]  ${role_id}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm role-show ${role_id}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log  ${stdout}
    [Return]  ${stdout}


Update Role
    [Arguments]  ${role}    ${feild}    ${value}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm role-update ${feild} ${value} ${role}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log  ${stdout}


Add Role And Verify
    [Arguments]  ${role}    ${role_to_add}
    Update Role    ${role}    --add    ${role_to_add}
    ${role_info}=    Get Role Info By Name    ${role}
#    Should Contain    ${role_info}    ${role_to_add}


Delete Role
    [Arguments]  ${role}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm role-delete ${role}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}


Delete Role And Verify
    [Arguments]  ${role}
    Delete Role    ${role}
    ${role_list}=    List Roles
    Should Not Contain    ${role_list}    ${role}
