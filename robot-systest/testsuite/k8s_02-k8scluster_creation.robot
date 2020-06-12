# Copyright 2020 Canonical Ltd.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

*** Settings ***
Library   OperatingSystem
Library   String
Library   Collections
Library   Process

Resource   %{ROBOT_DEVOPS_FOLDER}/lib/k8scluster_lib.robot

Variables   %{ROBOT_DEVOPS_FOLDER}/resources/k8s_02-k8scluster_creation_data.py

Suite Teardown   Run Keyword And Ignore Error   Test Cleanup

*** Test Cases ***
Add K8s Cluster To OSM
    [Tags]   k8scluster
    Create K8s Cluster  %{K8S_CREDENTIALS}  ${k8scluster_version}  %{VIM_TARGET}  %{VIM_MGMT_NET}  ${k8scluster_name}

List K8s Clusters
    [Tags]   k8scluster
    ${stdout}=    Get K8s Cluster
    Log To Console  \n${stdout}

Remove K8s Cluster from OSM
    [Tags]   k8scluster
    Delete K8s Cluster  ${k8scluster_name}

*** Keywords ***
Test Cleanup
    [Documentation]  Test Suit Cleanup: Deleting K8s Cluster
    Run Keyword If Test Failed  Delete K8s Cluster  ${k8scluster_name}
