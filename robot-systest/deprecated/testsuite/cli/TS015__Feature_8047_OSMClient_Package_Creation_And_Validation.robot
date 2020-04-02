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
# 1. Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com : 18-Dec-2019
##

*** Settings ***
Documentation    Test Suite to test OSMClient Package Createtion and Validation Tool
Library     OperatingSystem
Library     String
Library     Collections
Resource    ../../lib/cli/osm_package_tools_lib.robot

Suite Setup    Prerequisite For Test
Suite Teardown    Test Cleanup


*** Variables ***
${success_return_code}    0
${base_dir}    ${EXECDIR}
${pkg_dir}    ${CURDIR}${/}../../resource/cli/packages
${ns_pkg}    vEPC
${vnf_pkg}    vEPC


*** Test Cases ***
Test OSM NS Package Create
    [Tags]  comprehensive   feature8047
    Create OSM NS Package    ${ns_pkg}


Test OSM VNF Package Create
    [Tags]  comprehensive   feature8047
    Create OSM VNF Package    ${vnf_pkg}


Test OSM NS Package Validate
    [Tags]  comprehensive   feature8047
    Validate OSM NS Package    ${ns_pkg}


Test OSM VNF Package Validate
    [Tags]  comprehensive   feature8047
    Validate OSM VNF Package    ${vnf_pkg}


Test OSM VNF Package Build
    [Tags]  comprehensive   feature8047
    Build OSM VNF Package    ${vnf_pkg}


Test OSM NS Package Build
    [Tags]  comprehensive   feature8047
    Build OSM NS Package    ${ns_pkg}


*** Keywords ***
Prerequisite For Test
    Create Directory    ${pkg_dir}
    ${rc}   ${stdout}=      Run and Return RC and Output    cd ${pkg_dir}
    Should Be Equal As Integers    ${rc}    ${success_return_code}


Test Cleanup
    ${rc}   ${stdout}=      Run and Return RC and Output    cd ${base_dir}
    Should Be Equal As Integers    ${rc}    ${success_return_code}

    Remove Directory    ${pkg_dir}    recursive=${TRUE}