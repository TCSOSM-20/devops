#   Copyright 2020 Atos
#
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

*** Variables ***
${success_return_code}   0
${ns_launch_max_wait_time}   5min
${ns_launch_pol_time}   30sec
${ns_delete_max_wait_time}   1min
${ns_delete_pol_time}   15sec

*** Keywords ***
Get NST List
    ${rc}   ${stdout}=   Run and Return RC and Output   osm netslice-template-list
    log   ${stdout}
    log   ${rc}
    Should Be Equal As Integers   ${rc}   ${success_return_code}


Create NST
    [Arguments]   ${nst}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm netslice-template-create ${nst}
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    [Return]  ${stdout}


Delete NST
    [Arguments]   ${nst_id}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm netslice-template-delete ${nst_id}
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    WAIT UNTIL KEYWORD SUCCEEDS   ${delete_max_wait_time}   ${delete_pol_time}   Check For NST   ${nst_id}


Check For NST
    [Arguments]   ${nst_id}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm netslice-template-list | awk '{print $2}' | grep ${nst_id}
    Should Not Be Equal As Strings   ${stdout}   ${nst_id}

