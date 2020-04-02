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
# 1. Mrityunjay Yadav, Jayant Madavi : MY00514913@techmahindra.com : 27-Nov-19
##

*** Settings ***
Documentation    Test Suite to test manual scale-in/out cirros VNF and NS using osm-client
Library     OperatingSystem
Library     String
Library     Collections
Resource    ../../lib/cli/vnfd_lib.robot
Resource    ../../lib/cli/nsd_lib.robot
Resource    ../../lib/cli/ns_lib.robot
Resource    ../../lib/cli/vim_account_lib.robot
Library     ../../lib/custom_lib.py

Suite Teardown     Run Keyword And Ignore Error    Test Cleanup


*** Variables ***
# VNFD Details
@{vnfd_ids}
${vnfdPckgPath}    /descriptor-packages/vnfd/cirros_vnf
${vnfdPckg}    /build/cirros_vnf.tar.gz

# NSD Details
@{nsd_ids}
${nsdPckgPath}    /descriptor-packages/nsd/cirros_ns
${nsdPckg}    /build/cirros_ns.tar.gz
${scaling_group}    scaling_cirros_vnf
${vnf_member_index}    1

@{ns_ids}


*** Test Cases ***
Create VNF Descriptor Test
    [Documentation]  Build and onboard cirros VNF package with scaling parameter
    [Tags]    comprehensive   manual_scaling

    Build VNF Descriptor    ${vnfdPckgPath}
    ${vnfd_id}=    Create VNFD    '${CURDIR}${/}../../..${vnfdPckgPath}${vnfdPckg}'
    Append To List     ${vnfd_ids}       ${vnfd_id}


Create NS Descriptor Test
    [Documentation]  Build and onboard cirros NS package with scaling parameter
    [Tags]    comprehensive   manual_scaling

    Build NS Descriptor    ${nsdPckgPath}
    ${nsd_id}=    Create NSD    '${CURDIR}${/}../../..${nsdPckgPath}${nsdPckg}'
    Append To List     ${nsd_ids}       ${nsd_id}


Network Service Instance Test
    [Documentation]  Launch cirros ns with scaling parameter
    [Tags]    comprehensive   manual_scaling

    :FOR    ${vim_name}    IN    @{vim}
    \    Launch Network Services and Return    ${vim_name}


Perform VNF/VDU Scaling-out Operation Over Launched NS Test
    [Documentation]  scale-out cirros ns
    [Tags]    comprehensive   manual_scaling
    :FOR    ${ns}  IN   @{ns_ids}
    \   Perform VNF Scale-out Operation   ${ns}    ${vnf_member_index}    ${scaling_group}


Perform VNF/VDU Scaling-in Operation Over Launched NS Test
    [Documentation]  scale-in cirros ns
    [Tags]    comprehensive   manual_scaling
    :FOR    ${ns}  IN   @{ns_ids}
    \   Perform VNF Scale-in Operation   ${ns}    ${vnf_member_index}    ${scaling_group}


Delete NS Instance Test
    [Tags]    comprehensive   manual_scaling

    :FOR    ${ns}  IN   @{ns_ids}
    \   Delete NS   ${ns}


Delete NS Descriptor Test
    [Tags]    comprehensive   manual_scaling

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Delete NSD      ${nsd}


Delete VNF Descriptor Test
    [Tags]    comprehensive   manual_scaling

    :FOR    ${vnfd}  IN   @{vnfd_ids}
    \   Delete VNFD     ${vnfd}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suit Cleanup: Deliting Descriptor, instance and vim

    :FOR    ${ns}  IN   @{ns_ids}
    \   Delete NS   ${ns}

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Delete NSD      ${nsd}

    :FOR    ${vnfd}  IN   @{vnfd_ids}
    \   Delete VNFD     ${vnfd}

#    :FOR    ${vim_id}  IN   @{vim}
#    \   Delete Vim Account    ${vim_id}
