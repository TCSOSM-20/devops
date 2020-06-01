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
Get VNFDs List
    ${rc}   ${stdout}=   Run and Return RC and Output   osm vnfd-list
    log   ${stdout}
    log   ${rc}
    Should Be Equal As Integers   ${rc}   ${success_return_code}


Create VNFD
    [Arguments]   ${vnfd_pkg}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm vnfd-create ${vnfd_pkg}
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    ${lines}=  Get Line Count  ${stdout}
    ${last}=  Evaluate  ${lines} - 1
    ${id}=  Get Line  ${stdout}  ${last}
    [Return]  ${id}


Delete VNFD
    [Arguments]   ${vnfd_id}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm vnfd-delete ${vnfd_id}
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    WAIT UNTIL KEYWORD SUCCEEDS   ${delete_max_wait_time}   ${delete_pol_time}   Check For VNFD   ${vnfd_id}


Check For VNFD
    [Arguments]   ${vnfd_id}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm vnfd-list | awk '{print $2}' | grep ${vnfd_id}
    Should Not Be Equal As Strings   ${stdout}   ${vnfd_id}
