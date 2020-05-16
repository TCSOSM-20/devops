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
Create Network Service
    [Arguments]   ${nsd}   ${vim_name}   ${ns_name}   ${ns_config}   ${publickey}

    ${config_attr}   Set Variable If   '${ns_config}'!='${EMPTY}'   --config '${ns_config}'   \
    ${sshkeys_attr}   Set Variable If   '${publickey}'!='${EMPTY}'   --ssh_keys ${publickey}   \

    ${ns_id}=   Instantiate Network Service   ${ns_name}   ${nsd}   ${vim_name}   ${config_attr} ${sshkeys_attr}
    log   ${ns_id}

    WAIT UNTIL KEYWORD SUCCEEDS   ${ns_launch_max_wait_time}   ${ns_launch_pol_time}   Check For NS Instance To Configured   ${ns_name}
    Check For NS Instance For Failure   ${ns_name}
    [Return]  ${ns_id}

Instantiate Network Service
    [Arguments]   ${ns_name}   ${nsd}   ${vim_name}   ${ns_extra_args}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm ns-create --ns_name ${ns_name} --nsd_name ${nsd} --vim_account ${vim_name} ${ns_extra_args}
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    [Return]  ${stdout}

Get Vnf Management Ip Address
    [Arguments]   ${ns_id}   ${vnf_member_index}

    Should Not Be Empty   ${ns_id}
    Should Not Be Empty   ${vnf_member_index}
    ${rc}   ${stdout}=   Run and Return RC and Output   osm vnf-list --filter member-vnf-index-ref=${vnf_member_index} | grep ${ns_id} | awk '{print $14}' 2>&1
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    [Return]  ${stdout}

Check For NS Instance To Configured
    [Arguments]  ${ns_name}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm ns-list --filter name="${ns_name}"
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    Should Contain Any   ${stdout}   READY   BROKEN

Check For NS Instance For Failure
    [Arguments]  ${ns_name}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm ns-list --filter name="${ns_name}"
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    Should Not Contain   ${stdout}   BROKEN

Check For NS Instance To Be Deleted
    [Arguments]  ${ns}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm ns-list | awk '{print $2}' | grep ${ns}
    Should Not Be Equal As Strings   ${stdout}   ${ns}

Delete NS
    [Documentation]  Delete ns
    [Arguments]  ${ns}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm ns-delete ${ns}
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}

    WAIT UNTIL KEYWORD SUCCEEDS  ${ns_delete_max_wait_time}   ${ns_delete_pol_time}   Check For NS Instance To Be Deleted   ${ns}
