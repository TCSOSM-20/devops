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
Documentation     Library to obtain metrics from Prometheus.

Library   String
Library   Collections
Library   RequestsLibrary


*** Variables ***
${timeout}  1000
${max_retries}  1


*** Keywords ***
Get Metric
    [Documentation]     Get the instant value of a metric from Prometheus using multiple filter parameters.
    ...                 The filter parameters are given to this function in key=value format (one argument per key/value pair).
    ...                 Fails if the metric is not found or has multiple values.
    ...                 Examples of execution:
    ...                     \${metric}=  Get Metric  \${prometheus_ip}  \${prometheus_port}  \${metric}
    ...                     \${metric}=  Get Metric  \${prometheus_ip}  \${prometheus_port}  \${metric}  \${param1}=\${value1}  \${param2}=\${value2}

    [Arguments]  ${prometheus_ip}  ${prometheus_port}  ${metric}  @{filter_parameters}

    ${filter}=  Set Variable  ${EMPTY}
    FOR  ${param}  IN  @{filter_parameters}
        ${match}  ${param_name}  ${param_value} =  Should Match Regexp  ${param}  (.+)=(.+)  msg=Syntax error in filter parameters
        ${filter}=  Catenate  SEPARATOR=  ${filter}  ${param_name}="${param_value}",
    END
    ${resp}=  Execute Prometheus Instant Query  ${prometheus_host}  ${prometheus_port}  query=${metric}{${filter}}
    ${result_list}=  Convert To List  ${resp["data"]["result"]}
    ${results}=  Get Length  ${result_list}
    Should Not Be Equal As Numbers  0  ${results}  msg=Metric ${metric} not found  values=false
    Should Be Equal As Integers  1  ${results}  msg=Metric ${metric} with multiple values  values=false
    [Return]  ${result_list[0]["value"][1]}


Execute Prometheus Instant Query
    [Documentation]     Execute a Prometheus Instant Query using HTTP API.
    ...                 Return an inline json with the result of the query.
    ...                 The requested URL is the next: http://\${prometheus_ip}:\${prometheus_port}/api/v1/query?\${querystring}

    [Arguments]  ${prometheus_ip}  ${prometheus_port}  ${querystring}

    Create Session  prometheus  http://${prometheus_ip}:${prometheus_port}  timeout=${timeout}  max_retries=${max_retries}
    ${resp}=  Get Request  prometheus  /api/v1/query?${querystring}  timeout=${timeout}
    Status Should Be  200  ${resp}
    [Return]  ${resp.json()}
