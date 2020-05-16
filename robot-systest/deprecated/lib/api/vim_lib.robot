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
# 1. Feature 7829: Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com : 06-sep-2019
##


*** Keywords ***
Create Vim
    [Arguments]  ${vim_name}     ${account_type}     ${auth_url}     ${user}     ${password}     ${tenant}       ${description}

    &{request_data}=        Create Dictionary      vim_user=${user}    vim_password=${password}    vim_url=${auth_url}     vim_tenant_name=${tenant}   vim_type=${account_type}    description=${description}  name=${vim_name}

    &{headers}=    Create Dictionary     Authorization=Bearer ${token}      Content-Type=application/json   Accept=application/json

    Create Session    osmvim    ${HOST}    verify=${FALSE}    headers=${headers}

    LOG   ${request_data}
    ${res}=     Post Request    osmvim  ${create_vim_uri}   data=${request_data}
    log    ${res.content}
    Pass Execution If   ${res.status_code} in ${success_status_code_list}   Create Vim Request completed
    Get Vim ID      ${res.content}


Delete Vim
    [Arguments]  ${vim_id}

    ${uri} =	Catenate	SEPARATOR=/     ${create_vim_uri}      ${vim_id}
    ${resp}=    Delete Request   osmvim   ${uri}

    log   ${resp.content}
    Pass Execution If      ${resp.status_code} in ${success_status_code_list}   Delete Vim Request completed


Get Vim ID
    [Arguments]  ${res}

#    log to console      ${res}
    ${content}=     To Json     ${res}
    ${id}=      Get From Dictionary     ${content}	    id
    Set Suite Variable     ${vim_id}   ${id}
    log   Vim Id is ${vim_id}
