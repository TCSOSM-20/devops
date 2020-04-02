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
# 1. Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com : 08-nov-2019 : network slicing test library
##


*** Settings ***
Documentation    Test Suite to create hackfest basic nestwork service
Library     OperatingSystem
Library     String
Library     Collections
Resource    ../../lib/cli/vnfd_lib.robot
Resource    ../../lib/cli/nsd_lib.robot
Resource    ../../lib/cli/vim_account_lib.robot
Resource    ../../lib/cli/network_slicing_lib.robot
Library     ../../lib/custom_lib.py

Suite Teardown     Run Keyword And Ignore Error    Test Cleanup


*** Variables ***
${vnfd_id}
@{vnfd_ids}
${nsd_id}
@{nsd_ids}
${nst_id}
@{nsi_list}
${vnfdPckg}    slice_hackfest_vnfd.tar.gz
${nsdPckg}    slice_hackfest_nsd.tar.gz
${nstPckg}    slice_hackfest_nst.yaml
${vnfdftpPath}    https://osm-download.etsi.org/ftp/osm-5.0-five/6th-hackfest/packages/slice_hackfest_vnfd.tar.gz
${nsdftpPath}    https://osm-download.etsi.org/ftp/osm-5.0-five/6th-hackfest/packages/slice_hackfest_nsd.tar.gz
${nstftpPath}    https://osm-download.etsi.org/ftp/osm-5.0-five/6th-hackfest/packages/slice_hackfest_nst.yaml
${nst_config}    '{netslice-vld: [{name: mgmtnet, vim-network-name: mgmt}]}'


*** Test Cases ***
Create Slice Hackfest VNF Descriptor
    [Tags]   slice_hackfest    comprehensive
    [Documentation]  Create Slice Hackfest VNF Descriptor Test

    ${rc}   ${stdout}=      Run and Return RC and Output    wget -P '${CURDIR}${/}../../resource/cli/slice/' ${vnfdftpPath}
    ${vnfd_id}=    Create VNFD    '${CURDIR}${/}../../resource/cli/slice${/}${vnfdPckg}'
    Append To List     ${vnfd_ids}       ${vnfd_id}


Create Slice Hackfest NS Descriptor
    [Tags]   slice_hackfest    comprehensive
    [Documentation]  Create Slice Hackfest NS Descriptor Test

    ${rc}   ${stdout}=      Run and Return RC and Output    wget -P '${CURDIR}${/}../../resource/cli/slice/' ${nsdftpPath}
    ${nsd_id}=    Create NSD    '${CURDIR}${/}../../resource/cli/slice${/}${nsdPckg}'
    Append To List     ${nsd_ids}       ${nsd_id}


Create Slice Hackfest Network Slice Template
    [Tags]   slice_hackfest    comprehensive
    [Documentation]  Create Slice Hackfest Network Slice Template Test

#    set suite variable    ${nst_id}
    ${rc}   ${stdout}=      Run and Return RC and Output    wget -P '${CURDIR}${/}../../resource/cli/slice/' ${nstftpPath}
    ${nst_id}=    Create NST    '${CURDIR}${/}../../resource/cli/slice${/}${nstPckg}'
    Set Suite Variable    ${nst_id}


Instanciate Network Slice
    [Tags]  slice_hackfest    comprehensive
    [Documentation]  Instantiate Network Slice Test

    :FOR    ${vim_name}    IN    @{vim}
    \    Launch Network Slice Instance    ${vim_name}    ${nst_id}    ${nst_config}


Terminate Network Slice Instance
    [Tags]  slice_hackfest    comprehensive
    [Documentation]  Terminate Network Slice Instance Test

    :FOR    ${nsi}    IN    @{nsi_list}
    \    Delete Network Slice Instance    ${nsi}


*** Keywords ***
Test Cleanup
    [Documentation]  Test Suit Cleanup: delete NST, NSD and VNFD

    Delete NST    ${nst_id}

#    :FOR    ${nsi}    IN    @{nsi_list}
#    \    Delete Network Slice Instance    ${nsi}

    :FOR    ${nsd}  IN   @{nsd_ids}
    \   Delete NSD      ${nsd}

    :FOR    ${vnfd}  IN   @{vnfd_ids}
    \   Delete VNFD     ${vnfd}

#    :FOR    ${vim_id}  IN   @{vim}
#    \   Delete Vim Account    ${vim_id}
