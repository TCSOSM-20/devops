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


*** Settings ***
Documentation    Test suite to test osmclient python library
Library     OperatingSystem

Suite Setup    Setup OSM Client


*** Variables ***
${name}     helloworld-os
${user}     robottest
${password}     fred
${authurl}      https://169.254.169.245/
${type}     openstack
${desc}     a test vim
${tenant}    robottest


*** Test Cases ***
Get VIM Account List Test
    [Tags]    comprehensive    osmclient_lib
    [Documentation]    Using python's osmclient library to get vim account list

    ${vim_list}=    osmclient.get_vim_list
    log to console    ${vim_list}
    log  ${vim_list}


Get VNF Descriptor List Test
    [Tags]    comprehensive    osmclient_lib
    [Documentation]    Using python's osmclient library to get vnfd list

    ${vnfd_list}=    osmclient.get_vnfd_list
    log to console    ${vnfd_list}
    log  ${vnfd_list}


Get NS Descriptor List Test
    [Tags]    comprehensive    osmclient_lib
    [Documentation]    Using python's osmclient library to get nsd list

    ${nsd_list}=    osmclient.get_nsd_list
    log to console    ${nsd_list}
    log  ${nsd_list}


Create Vim Account Test
    [Tags]    comprehensive    osmclient_lib
    [Documentation]    Using python's osmclient library to create vim account
    [Template]    osmclient.create_vim_account
    ${name}  ${type}  ${user}  ${password}  ${authurl}  ${tenant}  ${desc}


Delete Vim Account Test
    [Tags]    comprehensive    osmclient_lib
    [Documentation]    Using python's osmclient library to delete vim account
    osmclient.delete_vim_account    ${name}


*** Keywords ***
Setup OSM Client
    evaluate    sys.path.append('${CURDIR}${/}../../lib/client_lib')    modules=sys
    ${host}=    Get Environment Variable    OSM_HOSTNAME    127.0.0.1
    Import Library    ClientLib    host=${host}    WITH NAME    osmclient
