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

*** Variables ***
${success_return_code}   0
${k8scluster_launch_max_wait_time}   2min
${k8scluster_launch_pol_time}   30sec
${k8scluster_delete_max_wait_time}   2min
${k8scluster_delete_pol_time}   15sec

*** Keywords ***
Create K8s Cluster
    [Arguments]   ${k8scluster_creds}   ${k8scluster_version}   ${k8scluster_vim}   ${k8scluster_net}   ${k8scluster_name}
    ${rc}   ${stdout}=   Run and Return RC and Output   osm k8scluster-add --creds ${k8scluster_creds} --version ${k8scluster_version} --vim ${k8scluster_vim} --k8s-nets '{"net1": "${k8scluster_net}"}' ${k8scluster_name} --description "Robot cluster"
    log   ${stdout}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    WAIT UNTIL KEYWORD SUCCEEDS  ${k8scluster_launch_max_wait_time}  ${k8scluster_launch_pol_time}   Check For K8s Cluster To Be Ready  ${k8scluster_name}
    [Return]  ${stdout}

Delete K8s Cluster
    [Arguments]   ${k8scluster_name}
    ${rc}   ${stdout}=   Run and Return RC and Output   osm k8scluster-delete ${k8scluster_name}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    WAIT UNTIL KEYWORD SUCCEEDS  ${k8scluster_delete_max_wait_time}   ${k8scluster_delete_pol_time}   Check For K8s Cluster To Be Deleted   ${k8scluster_name}

Get K8s Cluster
    ${rc}   ${stdout}=   Run and Return RC and Output   osm k8scluster-list
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    log   ${stdout}
    [Return]  ${stdout}

Check for K8s Cluster
    [Arguments]   ${k8scluster_name}
    ${rc}   ${stdout}=   Run and Return RC and Output   osm k8scluster-list --filter name="${k8scluster_name}"
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    [Return]  ${stdout}

Check For K8s Cluster To Be Deleted
    [Arguments]   ${k8scluster_name}
    ${rc}   ${stdout}=   Run and Return RC and Output   osm k8scluster-list --filter name="${k8scluster_name}" | awk '{print $2}' | grep ${k8scluster_name}
    Should Be Empty   ${stdout}

Check For K8s Cluster To Be Ready
    [Arguments]   ${k8scluster_name}
    ${rc}   ${stdout}=   Run and Return RC and Output   osm k8scluster-list --filter name="${k8scluster_name}" --filter _admin.operationalState="ENABLED" | awk '{print $2}' | grep ${k8scluster_name}
    Should Be Equal As Integers   ${rc}   ${success_return_code}
    Should Be Equal As Strings   ${stdout}   ${k8scluster_name}
