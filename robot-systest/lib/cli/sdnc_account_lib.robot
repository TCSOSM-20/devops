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


*** Variables ***
${success_return_code}    0
${name}     "OpenSite"
${user}     "admin"
${password}     "admin"
${ip}      "1.1.1.1"
${type}     "onos"
${port}     "5858"
${dpid}   ""


*** Keywords ***
Create SDNC Account
    [Documentation]  create new sdnc account

     ${rc}    ${stdout}=      Run and Return RC and Output	 osm sdnc-create --name ${name} --type ${type} --ip-address ${ip} --user ${user} --password ${password} --port ${port} --switch_dpid ${dpid}     return_rc=True
    log  ${rc}
    log  ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}


Get SDNC List
    [Documentation]  Get a sdnc account list

    ${rc}    ${stdout}=      Run and Return RC and Output	 osm sdnc-list
    log     ${stdout}


Show SDNC Account
    [Documentation]  Get sdnc account details

    ${rc}    ${stdout}=      Run and Return RC and Output	 osm sdnc-show ${name}     return_rc=True
    log  ${rc}
    log  ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}


Delete SDNC Account
    [Documentation]  Get sdnc account details

    ${rc}    ${stdout}=      Run and Return RC and Output	 osm sdnc-delete ${name}     return_rc=True
    log  ${rc}
    log  ${stdout}
    Should Be Equal As Integers    ${rc}    ${success_return_code}