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

*** Settings ***
Library           Collections


*** Variables ***
${success_return_code}   0
${slice_launch_max_wait_time}   5min
${slice_launch_pol_time}   30sec
${slice_delete_max_wait_time}   1min
${slice_delete_pol_time}   15sec

*** Keywords ***

Create Network Slice
    [Documentation]   Instantiates a NST and returns an instantiation id (nsi), verifying the slice is successfully instantiated
    ...               Parameters:
    ...                  nst: Name of the slice template
    ...                  vim_name: Name of the VIM entry already in OSM
    ...                  slice_name: Name of the slice instance
    ...                  slice_config: Extra parameters that might require the slice instantiation i.e. configuration attributes
    ...                  publickey: SSH public key of the local machine
    ...               Execution example:
    ...                  \${nsi}=   Create Network Slice   \${nst}   \${vim_name}   \${slice_name}   \${slice_config}   \${publickey}

    [Arguments]   ${nst}   ${vim_name}   ${slice_name}   ${slice_config}   ${publickey}

    ${config_attr}   Set Variable If   '${slice_config}'!='${EMPTY}'   --config '${slice_config}'   \
    ${sshkeys_attr}   Set Variable If   '${publickey}'!='${EMPTY}'   --ssh_keys ${publickey}   \

    ${nsi_id}=   Instantiate Network Slice   ${slice_name}   ${nst}   ${vim_name}   ${config_attr}   #${sshkeys_attr}
    log   ${nsi_id}

    WAIT UNTIL KEYWORD SUCCEEDS   ${slice_launch_max_wait_time}   ${slice_launch_pol_time}   Check For Network Slice Instance To Configured   ${slice_name}
    Check For Network Slice Instance For Failure   ${slice_name}
    [Return]  ${nsi_id}


Instantiate Network Slice
    [Documentation]   Instantiates a NST and returns an instantiation id (nsi)
    ...               Parameters:
    ...                  slice_name: Name of the slice instance
    ...                  nst: Name of the slice template
    ...                  vim_name: Name of the VIM entry already in OSM
    ...                  slice_extra_args: Extra parameters that might require the slice instantiation i.e. configuration attributes
    ...               Execution example:
    ...                  \${nsi}=   Instantiate Network Slice   \${slice_name}   \${nst}   \${vim_name}   \${config_attr}

    [Arguments]   ${slice_name}   ${nst}   ${vim_name}   ${slice_extra_args}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm nsi-create --nsi_name ${slice_name} --nst_name ${nst} --vim_account ${vim_name} ${slice_extra_args}
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    [Return]  ${stdout}


Get Slice Ns List
    [Documentation]   Retrieves the list of NS in a slice
    ...               Parameters:
    ...                  slice_name: Name of the slice instance
    ...               Execution example:
    ...                  \@{slice_ns_list}=   Get Slice Ns List   \${slice_name}

    [Arguments]   ${slice_name}

    Should Not Be Empty   ${slice_name}
    @{ns_list_string}=   Run and Return RC and Output   osm ns-list | grep ${slice_name} | awk '{print $4}' 2>&1
    # Returns a String of ns_id and needs to be converted into a list
    @{ns_list} =  Split String    ${ns_list_string}[1]
    Log List    ${ns_list}
    [Return]  @{ns_list}


Get Slice Ns List Except One
    [Documentation]   Retrieves the list of NS in a slice removing one from the list. This is done to save time in the tests, avoiding one VNF to ping itself.
    ...               Parameters:
    ...                  slice_name: Name of the slice instance
    ...                  exception_ns: Name of the ns that will not appear in the final list
    ...               Execution example:
    ...                  \@{slice_ns_list}=   Get Slice Ns List Except One   \${slice_name}   \${exception_ns}

    [Arguments]   ${slice_name}   ${exception_ns}

    Should Not Be Empty   ${slice_name}
    Should Not Be Empty   ${exception_ns}

    @{ns_list_string}=   Run and Return RC and Output   osm ns-list | grep ${slice_name} | awk '!/${exception_ns}/' | awk '{print $4}' 2>&1
    # Returns a String of ns_id and needs to be converted into a list
    @{ns_list} =  Split String    ${ns_list_string}[1]
    Log List    ${ns_list}
    [Return]  @{ns_list}


Get Slice Ns Count
    [Documentation]   Returns the count of all the NS in a slice
    ...               Parameters:
    ...                  slice_name: Name of the slice instance
    ...               Execution example:
    ...                  \${slice_ns_count}=   Get Slice Ns Count   \${slice_name}

    [Arguments]   ${slice_name}

    Should Not Be Empty   ${slice_name}
    ${rc}   ${stdout}=   Run and Return RC and Output   osm ns-list | grep ${slice_name} | wc -l 2>&1
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    [Return]  ${stdout}


Get Slice Vnf Ip Addresses
    [Documentation]   Retrieves the list of IP addresses that belong to each of the VNFs in the slice
    ...               Parameters:
    ...                  slice_name: Name of the slice instance
    ...               Execution example:
    ...                  \@{slice_ip_address_list}=   Get Slice Vnf Ip Addresses   \${slice_name}

    [Arguments]   ${slice_name}

    # Get all the ns_id in the slice
    @{slice_ns_list}  Get Slice Ns List   ${slice_name}
    log many   @{slice_ns_list}
    @{temp_list}=    Create List
    # For each ns_id in the list, get all the vnf_id and their IP addresses
    FOR   ${ns_id}   IN   @{slice_ns_list}
        log   ${ns_id}
        @{vnf_id_list}   Get Ns Vnf List   ${ns_id}
        # For each vnf_id in the list, get all its IP addresses
        @{ns_ip_list}   Get Ns Ip List   @{vnf_id_list}
        @{temp_list}=   Combine Lists   ${temp_list}    ${ns_ip_list}
    END
    Log List   ${temp_list}
    [Return]   @{temp_list}


Check For Network Slice Instance To Configured
    [Documentation]   Verify the slice has been instantiated
    ...               Parameters:
    ...                  slice_name: Name of the slice instance
    ...               Execution example:
    ...                  Check For Network Slice Instance To Configured   \${slice_name}

    [Arguments]  ${slice_name}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm nsi-list --filter name="${slice_name}"
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    Should Contain Any   ${stdout}   READY   BROKEN	configured


Check For Network Slice Instance For Failure
    [Documentation]   Verify the slice instance is not in failure
    ...               Parameters:
    ...                  slice_name: Name of the slice instance
    ...               Execution example:
    ...                  Check For Network Slice Instance For Failure   \${slice_name}

    [Arguments]  ${slice_name}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm nsi-list --filter name="${slice_name}"
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    Should Not Contain   ${stdout}   BROKEN


Delete NSI
    [Documentation]   Delete Network Slice Instance (NSI)
    ...               Parameters:
    ...                  slice_name: Name of the slice instance
    ...               Execution example:
    ...                  Delete NST   \${slice_name}

    [Arguments]  ${slice_name}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm nsi-delete ${slice_name}
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}

    WAIT UNTIL KEYWORD SUCCEEDS  ${slice_delete_max_wait_time}   ${slice_delete_pol_time}   Check For Network Slice Instance To Be Deleted   ${slice_name}


Check For Network Slice Instance To Be Deleted
    [Documentation]   Verify the slice instance is not present
    ...               Parameters:
    ...                  slice_name: Name of the slice instance
    ...               Execution example:
    ...                  Check For Network Slice Instance   \${slice_name}

    [Arguments]  ${slice_name}

    ${rc}   ${stdout}=   Run and Return RC and Output   osm nsi-list | awk '{print $2}' | grep ${slice_name}
    Should Not Be Equal As Strings   ${stdout}   ${slice_name}


