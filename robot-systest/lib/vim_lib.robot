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
Documentation     Library to manage VIM Targets.

Library   String
Library   Collections
Library   OperatingSystem

Resource   %{ROBOT_DEVOPS_FOLDER}/lib/prometheus_lib.robot


*** Variables ***
${success_return_code}   0
${delete_max_wait_time}   1min
${delete_pol_time}   15sec
${vim_status_max_wait_time}   1min
${vim_status_pol_time}   15sec


*** Keywords ***
Create VIM Target
    [Documentation]     Create a VIM Target in OSM.
    ...                 The optional parameters (such as 'config' or 'sdn_controller') are given to this function in name=value format. These parameters will be appended to the 'osm vim-create' command with the next syntax: --param_name=param_value
    ...                 Return the ID of the created VIM Target.
    ...                 Example of execution:
    ...                     \${vim_account_id}=  Create VIM Target  \${vim_name}  \${vim_user}  \${vim_password}  \${vim_auth_url}  \${vim_tenant}  \${vim_account_type}  config='{...}'

    [Arguments]  ${vim_name}  ${vim_user}  ${vim_password}  ${vim_auth_url}  ${vim_tenant}  ${vim_account_type}  @{optional_parameters}

    ${osm_vim_create_command}=  Set Variable  osm vim-create --name ${vim_name} --user ${vim_user} --password ${vim_password} --auth_url ${vim_auth_url} --tenant ${vim_tenant} --account_type ${vim_account_type}
    FOR  ${param}  IN  @{optional_parameters}
        ${match}  ${param_name}  ${param_value} =  Should Match Regexp  ${param}  (.+)=(.+)  msg=Syntax error in optional parameters
        ${osm_vim_create_command}=  Catenate  ${osm_vim_create_command}  --${param_name}=${param_value}
    END
    ${rc}  ${stdout}=  Run and Return RC and Output  ${osm_vim_create_command}
    log  ${stdout}
    Should Be Equal As Integers  ${rc}  ${success_return_code}
    [Return]  ${stdout}


Delete VIM Target
    [Arguments]   ${vim_name}

    ${rc}  ${stdout}=  Run Keyword And Continue On Failure  Run and Return RC and Output  osm vim-delete ${vim_name}
    log  ${stdout}
    Wait Until Keyword Succeeds  ${delete_max_wait_time}  ${delete_pol_time}  Check for VIM Target  ${vim_name}


Get VIM Targets
    ${rc}  ${stdout}=  Run and Return RC and Output  osm vim-list
    log  ${stdout}
    Should Be Equal As Integers  ${rc}  ${success_return_code}


Check for VIM Target
    [Arguments]  ${vim_name}

    ${rc}  ${stdout}=  Run and Return RC and Output  osm vim-list | awk '{print $2}' | grep ${vim_name}
    Should Not Be Equal As Strings  ${stdout}  ${vim_name}


Check for VIM Target Status
    [Arguments]  ${vim_name}  ${prometheus_host}  ${prometheus_port}

    ${vim_account_id}=  Get VIM Target ID  ${vim_name}
    Wait Until Keyword Succeeds  ${vim_status_max_wait_time}  ${vim_status_pol_time}  Check If VIM Target Is Available  ${vim_account_id}  ${prometheus_host}  ${prometheus_port}


Get VIM Target ID
    [Arguments]  ${vim_name}

    ${rc}  ${stdout}=  Run and Return RC and Output  osm vim-list | grep " ${vim_name} " | awk '{print $4}'
    Should Be Equal As Integers  ${rc}  ${success_return_code}
    Should Not Be Equal As Strings  ${stdout}  ${EMPTY}  msg=VIM Target '${vim_name}' not found  values=false
    [Return]  ${stdout}


Check If VIM Target Is Available
    [Arguments]  ${vim_account_id}  ${prometheus_host}  ${prometheus_port}

    ${metric}=  Get Metric  ${prometheus_host}  ${prometheus_port}  osm_vim_status  vim_account_id=${vim_account_id}
    Should Be Equal As Integers  ${metric}  1  msg=VIM Target '${vim_account_id}' is not active  values=false
