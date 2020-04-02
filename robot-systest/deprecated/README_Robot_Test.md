<!--
Copyright 2019 Tech Mahindra Limited

All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License"); you may
not use this file except in compliance with the License. You may obtain
a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations
under the License.
-->


# Step to run robot framework test standalone linux environment

All installation commands run using root user(`sudo su`)
## Step 1: Install python packages
Install below python packages using pip
>pip install python-magic pyangbind haikunator requests pyvcloud progressbar pathlib robotframework robotframework-seleniumlibrary robotframework-requests robotframework-jsonlibrary

## Step 2: Install linux packages
Install below linux packages
>curl http://osm-download.etsi.org/repository/osm/debian/ReleaseSIX/OSM%20ETSI%20Release%20Key.gpg | apt-key add -

>add-apt-repository -y "deb http://osm-download.etsi.org/repository/osm/debian/ReleaseSIX stable devops osmclient IM" && apt update

>curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -

>echo "deb [arch=amd64]  http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list

> apt-get install -y python-osmclient python-osm-im google-chrome-stable chromium-chromedriver

>./git-repo/devops/tools/OVF_converter/install.sh

## Step 3: checkout robot seed code
Checkout devops from gerrit
> git clone "https://osm.etsi.org/gerrit/osm/devops"

If robot seed code not merged to to master, pull it
> git pull "https://osm.etsi.org/gerrit/osm/devops" refs/changes/52/7852/4

## Step 4: Set environmet
for build test need to create env-file and provide below details and for Standalone testing export them
```
export OSM_HOSTNAME=<OSM server IP>
```

OpenStack Details
```
export OS_AUTH_URL=<auth url>
export OS_PASSWORD=<password>
export OS_PROJECT_NAME=<project name>
export OS_VIM_CONFIG=<config value>
```

VCD Details
```
export VCD_AUTH_URL=<VCD auth url>
export VCD_USERNAME=<VCD username>
export VCD_PASSWORD=<VCD password>
export VCD_TENANT_NAME=<VCD Tenant name>
export VCD_ORGANIZATION=<VCD Org name>
export VCD_VIM_CONFIG=<config value>
```

Note:- Optional
```
export NS_CONFIG=<NS Config Details>
e.g. export NS_CONFIG="'{vld: [ {name: mgmtnet, vim-network-name: mgmt}]}'"
```

## Step 5: Run Test
There are two ways to run the test-case:
* use `devops/robot-systest/run_test.sh` file and provide test-name(vim/smoke/sanity/comprehensive).
  > ./devops/robot-systest/run_test.sh -t smoke

* use `robot` command
  > robot -d path/to/report/dir -i test-tag-to-be-included -e test-tag-to-be-excluded path/to/testsuiet
  
  > robot -d devops/robot-systest/reports -i comprehensive devops/robot-systest/testsuite