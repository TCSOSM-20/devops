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
# 1. Feature 7829: Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com
##


*** Variables ***
${token}=  ${EMPTY}
${HOST}=  ${EMPTY}


*** Keywords ***
Get Auth Token
    [Tags]  auth_token

    ${nbi_host}=    Get Environment Variable    OSM_HOSTNAME
    ${passed}=    Run Keyword And Return Status    Should Contain    ${nbi_host}    :
    Run Keyword If    ${passed}    Set Dockerized Host    ${nbi_host}
    ...    ELSE    Set Standalone Host    ${nbi_host}

    Create Session    osmhit    ${HOST}    verify=${FALSE}    debug=1    headers=${HEADERS}

    Log Many    ${auth_token_uri}    @{data}    ${data}

    ${resp}=    Post Request    osmhit    ${auth_token_uri}    data=${data}
    log    ${resp}

    Pass Execution If   ${resp.status_code} in ${success_status_code_list}   Get Auth Token completed

    ${content}=     To Json   ${resp.content}
    ${t}=    Get From Dictionary	${content}	    _id

    Set Suite Variable     ${token}   ${t}


Set Dockerized Host
    [Arguments]  ${env_host}

    Set Suite Variable     ${HOST}   https://${env_host}


Set Standalone Host
    [Arguments]  ${env_host}

    Set Suite Variable     ${HOST}   https://${env_host}:9999
