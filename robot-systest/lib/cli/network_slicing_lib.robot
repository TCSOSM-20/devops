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
# 1. Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com : 08-nov-2019
##

*** Variables ***
${success_return_code}    0
${delete_max_wait_time}    1min
${delete_pol_time}    15sec
${ns_launch_max_wait_time}    5min
${ns_launch_pol_time}    30sec


*** Keywords ***
Create NST
    [Documentation]  Create nst at osm
    [Arguments]  ${nst_pkg}

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm nst-create ${nst_pkg}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log     ${stdout}
    [Return]  ${stdout}


Delete NST
    [Documentation]  delete nst at osm
    [Arguments]  ${nst}

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm nst-delete ${nst}
    Should Be Equal As Integers 	${rc}	  ${success_return_code}
    log     ${stdout}
    [Return]  ${stdout}


Launch Network Slice Instance
    [Arguments]  ${vim_name}    ${nst_name}    ${ns_config}=''

    ${nsi_name}=    GENERATE NAME
    Run Keyword If   ${ns_config}!=''   Create Network Slice With Config    ${nsi_name}    ${nst_name}    ${vim_name}    ${ns_config}
    ...    ELSE    Create Network Slice Without Config    ${nsi_name}    ${nst_name}    ${vim_name}

    WAIT UNTIL KEYWORD SUCCEEDS     ${ns_launch_max_wait_time}   ${ns_launch_pol_time}   Check For Network Slice Instance To Configured   ${nsi_name}
    Check For Network Slice Instance For Failure    ${nsi_name}


Create Network Slice With Config
    [Arguments]  ${nsi_name}    ${nst_name}    ${vim}    ${config}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm nsi-create --nsi_name ${nsi_name} --nst_name ${nst_name} --vim_account ${vim} --config ${config}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    log     ${stdout}
    Append To List     ${nsi_list}       ${nsi_name}


Create Network Slice Without Config
    [Arguments]  ${nsi_name}    ${nst_name}    ${vim}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm nsi-create --nsi_name ${nsi_name} --nst_name ${nst_name} --vim_account ${vim}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    log     ${stdout}
    Append To List     ${nsi_list}       ${nsi_name}


Check For Network Slice Instance For Failure
    [Arguments]  ${nsi_name}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm nsi-list --filter name="${nsi_name}"
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    log     ${stdout}
    Should Not Contain      ${stdout}   failed


Check For Network Slice Instance To Configured
    [Arguments]  ${nsi_name}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm nsi-list --filter name="${nsi_name}"
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    log     ${stdout}
    Should Contain Any      ${stdout}   configured    failed


Delete Network Slice Instance
    [Documentation]  Delete ns
    [Arguments]  ${nsi}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm nsi-delete ${nsi}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    log     ${stdout}

    WAIT UNTIL KEYWORD SUCCEEDS  ${delete_max_wait_time}   ${delete_pol_time}   Check For NSI Instance To Be Delete   ${nsi}


Check For NSI Instance To Be Delete
    [Arguments]  ${nsi}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm nsi-list
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    log     ${stdout}
    Should Not Contain      ${stdout}   ${nsi}
