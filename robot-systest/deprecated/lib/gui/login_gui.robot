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
${DESIRED_CAPABILITIES}    desired_capabilities
${BROWSER}        Chrome
${DELAY}          0
${VALID USER}     admin
${VALID PASSWORD}    admin
${LOGIN URL}      /auth/
${WELCOME URL}    /projects/
${NS LIST URL}    /packages/ns/list
${VNF LIST URL}    /packages/vnf/list


*** Keywords ***
Set Server URL
    ${env_host}=    Get Environment Variable    OSM_HOSTNAME
    ${passed}=    Run Keyword And Return Status    Should Contain    ${env_host}    :
    Run Keyword If    ${passed}    Set Dockerized Host
    ...    ELSE    Set Standalone Host    ${env_host}


Open Browser To Login Page
    ${chrome_options} =     Evaluate    sys.modules['selenium.webdriver'].ChromeOptions()    sys, selenium.webdriver
    Call Method    ${chrome_options}   add_argument    headless
    Call Method    ${chrome_options}   add_argument    disable-gpu
    Call Method    ${chrome_options}   add_argument    no-sandbox
    ${options}=     Call Method     ${chrome_options}    to_capabilities
    Open Browser    ${SERVER}${LOGIN URL}    ${BROWSER}    desired_capabilities=${options}
    Maximize Browser Window
    Set Selenium Speed    ${DELAY}
    Login Page Should Be Open


Login Page Should Be Open
    Element Text Should Be    //*[@id="main_content"]/div/div[2]/p    Sign in to start your session


Enter Credentials
    [Arguments]    ${username}    ${password}
    Input Text    name:username    ${username}
    Input Password    name:password    ${password}


Submit Credentials
    Click Button    //*[@id="main_content"]/div/div[2]/form/div[3]/div[2]/button


Home Page Should Be Open
    Location Should Be    ${SERVER}${WELCOME URL}
#    Element Should Contain    id:title_header    6e3a8415-9014-4100-9727-90e0150263be    ignore_case=True
    Element Attribute Value Should Be    //*[@id="main_content"]/div/div[2]/div[1]/div[1]/div/a    href    ${SERVER}${NS LIST URL}
    Element Attribute Value Should Be    //*[@id="main_content"]/div/div[2]/div[1]/div[2]/div/a    href    ${SERVER}${VNF LIST URL}


Set Dockerized Host

    Set Suite Variable     ${SERVER}   http://light-ui


Set Standalone Host
    [Arguments]  ${env_host}

    Set Suite Variable     ${SERVER}   http://${env_host}
