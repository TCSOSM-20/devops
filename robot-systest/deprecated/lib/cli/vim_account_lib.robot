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
# 1. Feature 7829: Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com : 06-sep-2019
##

*** Settings ***
Library     OperatingSystem
Library     String
Library     Collections
Library     ../custom_lib.py


*** Variables ***
${success_return_code}    0
${user}     "robottest"
${password}     "fred"
${authurl}      "https://127.0.0.1/"
${type}     "openstack"
${desc}     "a test vim"
${tenant}   "robottest2"


*** Keywords ***
Create Vim Account
    [Documentation]   Create a new vim account

    ${vim-name}=     Generate Random String  8  [NUMBERS]
    ${vim-name}=     Catenate  SEPARATOR=  vim_  ${vim-name}
    set global variable  ${vim-name}

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm vim-create --name ${vim-name} --user ${user} --password ${password} --auth_url ${authurl} --tenant ${tenant} --account_type ${type} --description ${desc}
    log  ${stdout}
    Should Be Equal As Integers 	${rc}    ${success_return_code}


Get Vim List
    [Documentation]  Get a vim account list

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm vim-list
    log     ${stdout}
    Log To Console  ${stdout}
    Should Be Equal As Integers 	${rc}    ${success_return_code}


Delete Vim Account
    [Documentation]  delete vim account details
    [Arguments]  ${vim_name}=${vim-name}

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm vim-delete ${vim_name}
    log  ${stdout}
    Should Be Equal As Integers 	${rc}    ${success_return_code}


VIM Setup To Launch Network Services
    [Documentation]  Setup a VIM to launch network services

    set global variable    @{vim}
    ${vmware_url}=  Get Environment Variable    VCD_AUTH_URL   ${EMPTY}
    ${openstack_url}=   Get Environment Variable    OS_AUTH_URL   ${EMPTY}
    ${vmware_vim}=    Run Keyword And Return If   '${vmware_url}'!='${EMPTY}'   Setup Vmware Vim   ${vmware_url}   'vmware'      'pytest system test'
    ${openstack_vim}=    Run Keyword And Return If   '${openstack_url}'!='${EMPTY}'   Setup Openstack Vim    ${openstack_url}    'openstack'   'pytest system test'
    Should Not Be Empty    ${vim}    VIM details not provided
    Log Many   @{vim}


Setup Openstack Vim
    [Documentation]  Openstack Vim Account Setup
    [Tags]    vim-setup
    [Arguments]  ${authurl}  ${type}     ${desc}

    ${user}=  Get Environment Variable    OS_USERNAME   ''
    ${password}=  Get Environment Variable    OS_PASSWORD   ''
    ${tenant}=  Get Environment Variable    OS_PROJECT_NAME   ''
    ${vim-config}=  Get Environment Variable    OS_VIM_CONFIG   ''
    ${vim_name}=    GENERATE NAME

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm vim-create --name ${vim_name} --user ${user} --password ${password} --auth_url ${authurl} --tenant ${tenant} --account_type ${type} --description ${desc} --config ${vim-config}
    log  ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    Sleep    30s    Wait for to get vim ready
    ${rc}   ${vim_detail}=      Run and Return RC and Output    osm vim-show ${vim_name}
    Should Contain    ${vim_detail}    "operationalState": "ENABLED"    msg=Openstack vim is not available    values=False
    Append To List     ${vim}       ${stdout}

    [Return]  ${stdout}


Setup Vmware Vim
    [Documentation]  Vmware Vim Account Setup
    [Tags]    vim-setup
    [Arguments]  ${authurl}  ${type}     ${desc}

    ${user}=  Get Environment Variable    VCD_USERNAME   ''
    ${password}=  Get Environment Variable    VCD_PASSWORD   ''
    ${tenant}=  Get Environment Variable    VCD_TENANT_NAME   ''
    ${vcd-org}=  Get Environment Variable    VCD_ORGANIZATION   ''
    ${vim-config}=  Get Environment Variable    VCD_VIM_CONFIG   ''
    ${vim_name}=    GENERATE NAME

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm vim-create --name ${vim_name} --user ${user} --password ${password} --auth_url ${authurl} --tenant ${tenant} --account_type ${type} --description ${desc} --config ${vim-config}
    log  ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    Sleep    30s    Wait for to get vim ready
    ${rc}   ${vim_detail}=      Run and Return RC and Output    osm vim-show ${vim_name}
    Should Contain    ${vim_detail}    "operationalState": "ENABLED"    msg=VMWare VCD vim is not available    values=False
    Append To List     ${vim}       ${stdout}

    [Return]  ${stdout}


Force Delete Vim Account
    [Documentation]  delete vim account details
    [Arguments]  ${vim_name}

    ${rc}   ${stdout}=      Run and Return RC and Output	    osm vim-delete ${vim_name}
    log  ${stdout}
    Should Be Equal As Integers 	${rc}    ${success_return_code}
