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
Library     OperatingSystem
Library     String
Library     Collections
Resource    ../../lib/cli/osm_platform_resiliancy_recovery_lib.robot
Library     ../../lib/custom_lib.py


*** Variables ***
${max_wait_time}    5min
${pol_time}    30sec
@{components}    osm_keystone.1    osm_lcm.1    osm_light-ui.1    osm_mon.1    osm_mongo.1    osm_nbi.1    osm_pol.1    osm_prometheus.1    osm_ro.1    osm_kafka.1    osm_zookeeper.1    osm_mysql.1


*** Test Cases ***
Feature 1413 - OSM platform resiliency to single component failure
    [Tags]  platform    resiliency
    [Documentation]  OSM platform resiliency test

    ${name}=    Get Random Item From List    ${components}
    Check If OSM Working
    WAIT UNTIL KEYWORD SUCCEEDS     2x   30sec   Check All Service Are Running
    Kill Docker Container    ${name}
    WAIT UNTIL KEYWORD SUCCEEDS     ${max_wait_time}   ${pol_time}   Check All Service Are Running
    Check If OSM Working


Feature 1412 - OSM platform recovery after major failure
    [Tags]  platform    recovery
    [Documentation]  OSM platform recovery

    Check If OSM Working
    WAIT UNTIL KEYWORD SUCCEEDS     2x   30sec   Check All Service Are Running
    :FOR    ${component}    IN    @{components}
    \    Kill Docker Container    ${component}
    WAIT UNTIL KEYWORD SUCCEEDS     ${max_wait_time}   ${pol_time}   Check All Service Are Running
    Check If OSM Working
