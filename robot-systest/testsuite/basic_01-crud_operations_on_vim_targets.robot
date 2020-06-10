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
Documentation     [BASIC-01] CRUD operations on VIM targets.
...               All tests will be performed over an Openstack VIM, and the credentials will be loaded from clouds.yaml file.

Resource   %{ROBOT_DEVOPS_FOLDER}/lib/vim_lib.robot

Variables   %{ROBOT_DEVOPS_FOLDER}/resources/basic_01-crud_operations_on_vim_targets_data.py


*** Test Cases ***
Create VIM Target Basic
    [Documentation]     Create a VIM Target only with the mandatory parameters.
    ...                 Checks the status of the VIM in Prometheus after it creation.
    [Tags]  vim

    ${rand}=  Generate Random String  8  [NUMBERS]
    ${vim_name}=  Catenate  SEPARATOR=_  ${vim_name_prefix}  ${rand}
    Set Suite Variable  ${vim_name}
    ${created_vim_account_id}=  Create VIM Target  ${vim_name}  ${vim_user}  ${vim_password}  ${vim_auth_url}  ${vim_tenant}  ${vim_account_type}
    Set Suite Variable  ${created_vim_account_id}
    Check for VIM Target Status  ${vim_name}  ${prometheus_host}  ${prometheus_port}


Delete VIM Target By Name
    [Documentation]     Delete the VIM Target created in previous test-case by its name.
    ...                 Checks whether the VIM Target was created or not before perform the deletion.
    [Tags]  vim  cleanup

    ${vim_account_id}=  Get VIM Target ID  ${vim_name}
    Should Be Equal As Strings  ${vim_account_id}  ${created_vim_account_id}
    Delete VIM Target  ${vim_name}


Create VIM Target With Extra Config
    [Documentation]     Create a VIM Target using the extra parameter 'config'.
    ...                 Checks the status of the VIM in Prometheus after it creation.
    [Tags]  vim

    ${rand}=  Generate Random String  8  [NUMBERS]
    ${vim_name}=  Catenate  SEPARATOR=_  ${vim_name_prefix}  ${rand}
    Set Suite Variable  ${vim_name}
    ${created_vim_account_id}=  Create VIM Target  ${vim_name}  ${vim_user}  ${vim_password}  ${vim_auth_url}  ${vim_tenant}  ${vim_account_type}  config=${vim_config}
    Set Suite Variable  ${created_vim_account_id}
    Check for VIM Target Status  ${vim_name}  ${prometheus_host}  ${prometheus_port}


Delete VIM Target By ID
    [Documentation]     Delete the VIM Target created in previous test-case by its ID.
    ...                 Checks whether the VIM Target was created or not before perform the deletion.
    [Tags]  vim  cleanup

    ${vim_account_id}=  Get VIM Target ID  ${vim_name}
    Should Be Equal As Strings  ${vim_account_id}  ${created_vim_account_id}
    Delete VIM Target  ${vim_account_id}

