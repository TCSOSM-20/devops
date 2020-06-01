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

*** Settings ***
Library   String


*** Variables ***
${success_return_code}   0
${delete_max_wait_time}   1min
${delete_pol_time}   15sec


*** Keywords ***
Get NSDs List
    ${rc}   ${stdout}=   Run and Return RC and Output   osm nsd-list
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}


Create NSD
    [Arguments]   ${nsd_pkg}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm nsd-create ${nsd_pkg}
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    ${lines}=  Get Line Count  ${stdout}
    ${last}=  Evaluate  ${lines} - 1
    ${id}=  Get Line  ${stdout}  ${last}
    [Return]  ${id}


Delete NSD
    [Arguments]   ${nsd_id}

    ${rc}   ${stdout}=   Run Keyword And Continue On Failure   Run and Return RC and Output   osm nsd-delete ${nsd_id}
    log   ${stdout}
    WAIT UNTIL KEYWORD SUCCEEDS   ${delete_max_wait_time}   ${delete_pol_time}   Check For NSD   ${nsd_id}


Check For NSD
    [Arguments]   ${nsd_id}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm nsd-list | awk '{print $2}' | grep ${nsd_id}
    Should Not Be Equal As Strings   ${stdout}   ${nsd_id}
