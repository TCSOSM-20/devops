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
${ns_action_max_wait_time}   1min
${ns_action_pol_time}   15sec
${vnf_scale_max_wait_time}   5min
${vnf_scale_pol_time}   30sec


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

Execute NS Action
    [Documentation]     Execute an action over the desired NS.
    ...                 Parameters are given to this function in key=value format (one argument per key/value pair).
    ...                 Return the ID of the operation associated to the executed action.
    ...                 Examples of execution:
    ...                     \${ns_op_id}=  Execute NS Action  \${ns_name}  \${ns_action}  \${vnf_member_index}
    ...                     \${ns_op_id}=  Execute NS Action  \${ns_name}  \${ns_action}  \${vnf_member_index}  \${param1}=\${value1}  \${param2}=\${value2}

    [Arguments]  ${ns_name}  ${ns_action}  ${vnf_member_index}  @{action_params}

    ${params}=  Set Variable  ${EMPTY}
    FOR  ${param}  IN  @{action_params}
        ${match}  ${param_name}  ${param_value} =  Should Match Regexp  ${param}  (.+)=(.+)  msg=Syntax error in parameters
        ${params}=  Catenate  SEPARATOR=  ${params}  "${param_name}":"${param_value}",
    END
    ${osm_ns_action_command}=  Set Variable  osm ns-action --action_name ${ns_action} --vnf_name ${vnf_member_index}
    ${osm_ns_action_command}=  Run Keyword If  '${params}'!='${EMPTY}'  Catenate  ${osm_ns_action_command}  --params '{${params}}'
    ...  ELSE  Set Variable  ${osm_ns_action_command}
    ${osm_ns_action_command}=  Catenate  ${osm_ns_action_command}  ${ns_name}
    ${rc}  ${stdout}=  Run and Return RC and Output  ${osm_ns_action_command}
    Should Be Equal As Integers  ${rc}  ${success_return_code}  msg=${stdout}  values=False
    Wait Until Keyword Succeeds  ${ns_action_max_wait_time}  ${ns_action_pol_time}  Check For NS Operation Completed  ${stdout}
    [Return]  ${stdout}


Execute Manual VNF Scale
    [Documentation]     Execute a manual VNF Scale action.
    ...                 The parameter 'scale_type' must be SCALE_IN or SCALE_OUT.
    ...                 Return the ID of the operation associated to the executed scale action.

    [Arguments]  ${ns_name}  ${vnf_member_index}  ${scaling_group}  ${scale_type}

    Should Contain Any  ${scale_type}  SCALE_IN  SCALE_OUT  msg=Unknown scale type: ${scale_type}  values=False
    ${osm_vnf_scale_command}=  Set Variable  osm vnf-scale --scaling-group ${scaling_group}
    ${osm_vnf_scale_command}=  Run Keyword If  '${scale_type}'=='SCALE_IN'  Catenate  ${osm_vnf_scale_command}  --scale-in
    ...  ELSE  Catenate  ${osm_vnf_scale_command}  --scale-out
    ${osm_vnf_scale_command}=  Catenate  ${osm_vnf_scale_command}  ${ns_name}  ${vnf_member_index}
    ${rc}  ${stdout}=  Run and Return RC and Output  ${osm_vnf_scale_command}
    Should Be Equal As Integers  ${rc}  ${success_return_code}  msg=${stdout}  values=False
    Wait Until Keyword Succeeds  ${ns_action_max_wait_time}  ${ns_action_pol_time}  Check For NS Operation Completed  ${stdout}
    [Return]  ${stdout}


Get Operations List
    [Arguments]  ${ns_name}

    ${rc}  ${stdout}=  Run and Return RC and Output  osm ns-op-list ${ns_name}
    log  ${stdout}
    log  ${rc}
    Should Be Equal As Integers  ${rc}  ${success_return_code}


Check For NS Operation Completed
    [Documentation]     Check wheter the status of the desired operation is "COMPLETED" or not.

    [Arguments]  ${ns_operation_id}

    ${rc}  ${stdout}=  Run and Return RC and Output  osm ns-op-show ${ns_operation_id} --literal | yq r - operationState
    log  ${stdout}
    Should Be Equal As Integers  ${rc}  ${success_return_code}
    Should Contain  ${stdout}  COMPLETED  msg=Timeout waiting for ns-action with id ${ns_operation_id}  values=False


Get Ns Vnfr Ids
    [Documentation]     Return a list with the IDs of the VNF records of a NS instance.

    [Arguments]  ${ns_id}

    ${rc}  ${stdout}=  Run and Return RC and Output  osm vnf-list | grep ${ns_id} | awk '{print $2}' 2>&1
    Should Be Equal As Integers  ${rc}  ${success_return_code}  msg=${stdout}  values=False
    @{vdur} =  Split String  ${stdout}
    [Return]  @{vdur}


Get Vnf Vdur Names
    [Documentation]     Return a list with the names of the VDU records of a VNF instance.

    [Arguments]  ${vnf_id}

    ${rc}  ${stdout}=  Run and Return RC and Output  osm vnf-show ${vnf_id} --literal | yq r - vdur.*.name
    Should Be Equal As Integers  ${rc}  ${success_return_code}  msg=${stdout}  values=False
    @{vdur} =  Split String  ${stdout}
    [Return]  @{vdur}

