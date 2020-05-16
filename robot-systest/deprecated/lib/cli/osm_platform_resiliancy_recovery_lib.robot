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
# 1. Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com : 08-nov-2019
##


*** Variables ***
${success_return_code}    0
${er_replicas}    0/1


*** Keywords ***
Check If OSM Working

    ${rc}   ${stdout}=      Run and Return RC and Output    osm vnfpkg-list
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    ${rc}   ${stdout}=      Run and Return RC and Output    osm vim-list
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}


Check All Service Are Running

    ${rc}   ${stdout}=      Run and Return RC and Output    docker service ls
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}
    Should Not Contain      ${stdout}   ${er_replicas}


Kill Docker Container
    [Arguments]  ${name}

    ${rc}   ${stdout}=      Run and Return RC and Output    docker rm -f \$(docker ps |grep -i ${name}|awk '{print $1}')
    log     ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}