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

*** Variables ***
${success_return_code}    0
${delete_max_wait_time}    1min
${delete_pol_time}    15sec


*** Keywords ***
Get NSDs List
    [Documentation]  Get nsds list

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm nsd-list
    log     ${stdout}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}


Create NSD
    [Documentation]  Create nsd at osm
    [Arguments]  ${nsd_pkg}

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm nsd-create ${nsd_pkg}
    log     ${stdout}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    [Return]  ${stdout}


Delete NSD
    [Documentation]  Delete nsd
    [Arguments]  ${nsd_id}

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm nsd-delete ${nsd_id}
    log     ${stdout}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    WAIT UNTIL KEYWORD SUCCEEDS    ${delete_max_wait_time}   ${delete_pol_time}   Check For NSD   ${nsd_id}


Check For NSD
    [Arguments]  ${nsd_id}

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm nsd-list
    log     ${stdout}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    Should Not Contain      ${stdout}   ${nsd_id}


Force Delete NSD
    [Documentation]  Forcely Delete nsd
    [Arguments]  ${nsd_id}

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm nsd-delete ${nsd_id}
    log     ${stdout}
    Should Be Equal As Integers 	${rc}   ${success_return_code}


Build NS Descriptor
    [Documentation]  Build NS Descriptor from the descriptor-packages
    [Arguments]  ${nsd path}

    ${rc}   ${stdout}=      Run and Return RC and Output	    make -C '${CURDIR}${/}../../..${nsd path}'
    log     ${stdout}
    Should Be Equal As Integers 	${rc}   ${success_return_code}
