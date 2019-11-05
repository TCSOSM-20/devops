#!/usr/bin/env bash

##
# Copyright 2019 Tech Mahindra Limited
#
# All Rights Reserved.
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
##

## Change log:
# 1. Feature 7829: Mrityunjay Yadav, Jayant Madavi : MY00514913@techmahindra.com : 06-Sep-2019
# Entry script to start the vim, smoke, openstack_stage_4 and comprehensive test using Robot Framework as a Automation Test Framework
##

BASEDIR=$(dirname "$0")
TOPDIR=$(dirname "$BASEDIR")
DESCRIPTOR_DIR=$TOPDIR/descriptor-packages


robot_prerequisite(){
    echo -e "\nInstalling robot requirements"
    # installing python packages
    pip install haikunator requests robotframework robotframework-seleniumlibrary robotframework-requests
}

while getopts ":t:-:" o; do
    case "${o}" in
        t)
            TEST=${OPTARG}
            ;;
        -)
            [[ "${OPTARG}" == "do_install" ]] && robot_prerequisite && continue
            ;;
        \?)
            echo -e "Invalid option: '-$OPTARG'\n" >&2
            exit 1
            ;;
    esac
done

if [[ -z $TEST ]]; then
    printf "Test not provided. \nRunning default test: smoke\n"
    TEST="smoke"
fi

if [[ "$TEST" == "vim" ]]; then
    echo "Robot Framework Vim Test"
    robot -d $BASEDIR/reports -i vim $BASEDIR/testsuite/
    exit 0
elif [[ "$TEST" == "smoke" ]]; then
    echo "Robot Framework SMOKE test"
    robot --removekeywords tag:vim-setup --removekeywords WUKS -d $BASEDIR/reports -i smoke $BASEDIR/testsuite/
    exit 0
elif [[ "$TEST" == "sanity" ]]; then
    echo "Robot Framework Cirros VNF Test"
    mkdir -p $BASEDIR/images/cache
    if [[ ! -z $OS_AUTH_URL ]]; then
        (openstack image show cirros-0.3.5-x86_64-disk.img) || (wget -r -nc http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img -O $BASEDIR/images/cache/cirros-0.3.5-x86_64-disk.img && make $BASEDIR/images/cache/cirros-0.3.5-x86_64-disk.img && openstack image create --file $BASEDIR/images/cache/cirros-0.3.5-x86_64-disk.img cirros-0.3.5-x86_64-disk.img)
    fi
    if [[ ! -z $VCD_AUTH_URL ]]; then
#        TODO: Check for image over VIM before downloading
        if [[ ! -s $BASEDIR/images/cache/cirros-0.3.5-x86_64-disk.img ]]; then
            wget -r -nc http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img -O $BASEDIR/images/cache/cirros-0.3.5-x86_64-disk.img
        fi
        ovf_converter $BASEDIR/images/cache/cirros-0.3.5-x86_64-disk.img -n cirros
        python $TOPDIR/tools/vmware_ovf_upload.py $VCD_AUTH_URL $VCD_USERNAME $VCD_PASSWORD $VCD_ORGANIZATION $BASEDIR/images/cache/cirros.ovf
    fi
    robot --removekeywords tag:vim-setup --removekeywords WUKS -d $BASEDIR/reports -i sanity $BASEDIR/testsuite/
    exit 0
elif [[ "$TEST" == "comprehensive" ]]; then
    echo "Robot Framework Comprehensive Test"
    echo "Installing chrome driver and chrome for UI testing"
    # installing chrome driver and chrome for UI testing
    curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
    echo "deb [arch=amd64]  http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
    apt-get update && apt-get -y install google-chrome-stable chromium-chromedriver
    echo "Checking of image over VIMs"
    mkdir -p $BASEDIR/images/cache
    if [[ ! -z $OS_AUTH_URL ]]; then
        (openstack image show ubuntu1604) || (wget -r -nc https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img -O $BASEDIR/images/cache/xenial-server-cloudimg-amd64-disk1.img && make $BASEDIR/images/cache/xenial-server-cloudimg-amd64-disk1.img && openstack image create --file $BASEDIR/images/cache/xenial-server-cloudimg-amd64-disk1.img ubuntu1604)
        (openstack image show hackfest3-mgmt) || (wget -r -nc https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img -O $BASEDIR/images/cache/xenial-server-cloudimg-amd64-disk1.img && make $BASEDIR/images/cache/xenial-server-cloudimg-amd64-disk1.img && openstack image create --file $BASEDIR/images/cache/xenial-server-cloudimg-amd64-disk1.img hackfest3-mgmt)
    fi
    if [[ ! -z $VCD_AUTH_URL ]]; then
#        TODO: Check for image over VIM before downloading
        if [[ ! -s $BASEDIR/images/cache/xenial-server-cloudimg-amd64-disk1.img ]]; then
            wget -r -nc https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img -O $BASEDIR/images/cache/xenial-server-cloudimg-amd64-disk1.img
        fi
        ovf_converter $BASEDIR/images/cache/xenial-server-cloudimg-amd64-disk1.img -n ubuntu1604
        python $TOPDIR/tools/vmware_ovf_upload.py $VCD_AUTH_URL $VCD_USERNAME $VCD_PASSWORD $VCD_ORGANIZATION $BASEDIR/images/cache/ubuntu1604.ovf
    fi
    robot --removekeywords tag:vim-setup --removekeywords WUKS -d $BASEDIR/reports -i comprehensive $BASEDIR/testsuite/
    exit 0
else
    echo "wrong test provided"
    exit 1
fi

exit 1
