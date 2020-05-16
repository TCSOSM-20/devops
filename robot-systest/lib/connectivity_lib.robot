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

*** Keywords ***
Test Connectivity
    [Arguments]  ${host}

    ${result}  Run Process  ping -c 5 -W 1 ${host} > /dev/null && echo OK  shell=True
    Log     all output: ${result.stdout}
    Should Contain  ${result.stdout}  OK
