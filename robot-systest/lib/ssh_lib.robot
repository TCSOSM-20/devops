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

*** Keywords ***
Test SSH Connection
    [Arguments]   ${host}   ${username}   ${password}   ${privatekey}

    Open Connection     ${host}
    Run Keyword If   '${password}'!='${EMPTY}'   Login   ${username}   ${password}
    ...   ELSE   Login With Public Key   ${username}   ${privatekey}
    Execute Command   hostname
    Close All Connections

Check If remote File Exists
    [Arguments]   ${host}   ${username}   ${password}   ${privatekey}   ${file}

    Open Connection   ${host}
    Run Keyword If   '${password}'!='${EMPTY}'  Login  ${username}  ${password}
    ...   ELSE   Login With Public Key  ${username}  ${privatekey}
    ${rc}=   Execute Command   ls ${file} >& /dev/null   return_stdout=False   return_rc=True
    Close All Connections
    Should Be Equal As Integers   ${rc}   0

Get Remote File Content
    [Arguments]  ${host}  ${username}  ${password}  ${privatekey}   ${file}

    Open Connection     ${host}
    Run Keyword If   '${password}'!='${EMPTY}'  Login  ${username}  ${password}
    ...   ELSE   Login With Public Key  ${username}  ${privatekey}
    ${output}=   Execute Command   cat ${file}
    Close All Connections
    [Return]   ${output}

Execute Remote Command Check Rc Return Output
    [Arguments]   ${host}   ${username}   ${password}   ${privatekey}   ${command}

    Open Connection   ${host}
    Run Keyword If   '${password}'!='${EMPTY}'  Login  ${username}  ${password}
    ...   ELSE   Login With Public Key  ${username}  ${privatekey}
    ${stdout}   ${rc}=   Execute Command   ${command}   return_rc=True   return_stdout=True
    log   ${rc}
    log   ${stdout}
    Close All Connections
    Should Be Equal As Integers   ${rc}   0
    [Return]   ${stdout}