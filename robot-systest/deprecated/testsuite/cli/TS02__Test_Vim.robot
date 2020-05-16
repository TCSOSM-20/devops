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


*** Settings ***
Documentation    Test suiet to create/delete vim account via osmclient
Library     OperatingSystem
Library     Collections
Resource    ../../lib/cli/vim_account_lib.robot


*** Test Cases ***
Create Vim Account Test
    [Tags]  smoke    vim

    Create Vim Account


Get Vim Accounts List Test
    [Tags]  vim

    Get Vim List


Delete Vim Account Test
    [Tags]  smoke    vim

    Delete Vim Account
