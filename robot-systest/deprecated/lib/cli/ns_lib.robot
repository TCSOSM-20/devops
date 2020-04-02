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
# 1. Feature 7829: Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com : 06-aug-2019 : Improvement to the code, robot framework initial seed code.
##


*** Variables ***
${success_return_code}    0
${ns_launch_max_wait_time}    5min
${ns_launch_pol_time}    30sec
${ns_delete_max_wait_time}    1min
${ns_delete_pol_time}    15sec
${nsconfig}

*** Keywords ***
Get NS List
    [Documentation]  Get ns instance list

    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-list
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}


Get NS Instance ID
    [Arguments]    ${ns_name}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-list --filter name="${ns_name}" | awk 'NR==4{print $4}'
    log     ${stdout}
    [Return]    ${stdout}


Verify All JUJU Applications Status
    [Arguments]    ${ns}    ${api_ip}    ${api_port}    ${username}    ${password}    ${api_cert_path}

    ${juju_model}=    Get NS Instance ID    ${ns}

    Import Library    robot_juju.JujuLibrary    ${api_ip}    ${api_port}    ${juju_model}    ${username}    ${password}    ${api_cert_path}
    Assert status of applications is  ${status_active}


Launch Network Services and Return
    [Arguments]  ${vim_name}  ${ns_config}=''
    [Documentation]  Get Configuration parameter to create Newtork service

    Run Keyword If    ${ns_config}==''    Get NS Config
    ...  ELSE  Set NS Config    ${ns_config}
    Log To Console    \n${nsconfig}
    Should Not Be Empty    ${nsd_ids}    There are no NS descriptors to launch the NS
    :FOR    ${nsd}    IN    @{nsd_ids}
    \    ${ns_name}=    GENERATE NAME
    \    Append To List     ${ns_ids}       ${ns_name}
    \    Create Network Service    ${nsd}   ${vim_name}    ${ns_name}    ${nsconfig}


Set NS Config
    [Arguments]   ${ns_config}
    [Documentation]  Set NS Configuration variable

    ${nsconfig}=    Get Variable Value    ${ns_config}    ''
    Set Test Variable    ${nsconfig}


Get NS Config
    [Documentation]  Get NS Configuration from Environment Variable

    ${nsconfig}=    Get Environment Variable    NS_CONFIG    ''
    Set Test Variable    ${nsconfig}


Create Network Service
    [Documentation]  Create ns at osm
    [Arguments]  ${nsd}   ${vim_name}    ${ns_name}    ${ns_config}

    Run Keyword If   ${ns_config}!=''   Create Network Service With Config    ${nsd}    ${vim_name}    ${ns_name}    ${ns_config}
    ...    ELSE    Create Network Service Without Config    ${nsd}   ${vim_name}    ${ns_name}

    WAIT UNTIL KEYWORD SUCCEEDS     ${ns_launch_max_wait_time}   ${ns_launch_pol_time}   Check For NS Instance To Configured   ${ns_name}
    Check For NS Instance For Failure    ${ns_name}


Create Network Service Without Config
    [Documentation]  Create ns at osm
    [Arguments]  ${nsd}   ${vim_name}    ${ns_name}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-create --ns_name ${ns_name} --nsd_name ${nsd} --vim_account ${vim_name}
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}


Create Network Service With Config
    [Documentation]  Create ns at osm
    [Arguments]  ${nsd}   ${vim_name}    ${ns_name}    ${ns_config}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-create --ns_name ${ns_name} --nsd_name ${nsd} --vim_account ${vim_name} --config ${ns_config}
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}


Delete NS
    [Documentation]  Delete ns
    [Arguments]  ${ns}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-delete ${ns}
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}

    WAIT UNTIL KEYWORD SUCCEEDS  ${ns_delete_max_wait_time}   ${ns_delete_pol_time}   Check For NS Instance To Be Delete   ${ns}


Check For NS Instance To Configured
    [Arguments]  ${ns_name}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-list --filter name="${ns_name}"
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    Should Contain Any      ${stdout}   READY    BROKEN


Check For NS Instance For Failure
    [Arguments]  ${ns_name}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-list --filter name="${ns_name}"
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    Should Not Contain      ${stdout}   BROKEN


Check For NS Instance To Be Delete
    [Arguments]  ${ns}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-list
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    Should Not Contain      ${stdout}   ${ns}


Force Delete NS
    [Documentation]  Forcely Delete ns
    [Arguments]  ${ns}

    ${rc}   ${stdout}=      Run and Return RC and Output    osm ns-delete ${ns}
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    WAIT UNTIL KEYWORD SUCCEEDS    ${ns_delete_max_wait_time}   ${ns_delete_pol_time}   Check For NS Instance To Be Delete   ${ns}


Perform VNF Scale-in Operation
    [Arguments]  ${ns}    ${vnf_member}    ${scaling_group}

    ${rc}    ${nsr}=    Run and Return RC and Output    osm ns-show ${ns} --literal
    ${scaled_vnf}=    Get Scaled Vnf    ${nsr}
    log to console  Scaled VNF befor scale-in operation is ${scaled_vnf}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm vnf-scale --scale-in --scaling-group ${scaling_group} ${ns} ${vnf_member}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    log     ${stdout}
    Sleep    1m    Waiting for scale-in operation to complete
    ${rc}    ${nsr}=    Run and Return RC and Output    osm ns-show ${ns} --literal
    ${scaled_vnf}=    Get Scaled Vnf    ${nsr}
    log to console  Scaled VNF after scale-in operation is ${scaled_vnf}


Perform VNF Scale-out Operation
    [Arguments]  ${ns}    ${vnf_member}    ${scaling_group}

    ${rc}    ${nsr}=    Run and Return RC and Output    osm ns-show ${ns} --literal
    ${scaled_vnf}=    Get Scaled Vnf    ${nsr}
    log to console  Scaled VNF befor scale-out operation is ${scaled_vnf}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm vnf-scale --scale-out --scaling-group ${scaling_group} ${ns} ${vnf_member}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    log     ${stdout}
    Sleep    1m    Waiting for scale-out operation to complete
    ${rc}    ${nsr}=    Run and Return RC and Output    osm ns-show ${ns} --literal
    ${scaled_vnf}=    Get Scaled Vnf    ${nsr}
    log to console  Scaled VNF befor scale-out operation is ${scaled_vnf}
