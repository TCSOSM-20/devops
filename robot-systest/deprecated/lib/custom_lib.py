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
# Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com
##̥


import random
from haikunator import Haikunator
import yaml
from os.path import basename
import hashlib

from robot.api import logger
from robot.api.deco import keyword


def generate_name():
    haikunator = Haikunator()
    name = haikunator.haikunate(delimiter='_', token_length=2)
    return name


def get_random_item_from_list(l):
    assert isinstance(l, list), "List should be provided"
    return random.choice(l)


def get_scaled_vnf(nsr):
    nsr = yaml.load(nsr)
    if 'scaling-group' in nsr['_admin']:
        return nsr['_admin']['scaling-group'][0]['nb-scale-op']
    else:
        return 0


@keyword('Get File Name From Path')
def get_filename(path):
    filename = basename(path)
    return filename, filename.split('.')[0]


@keyword('Generate MD5')
def generate_md5(fpath):
    hash_md5 = hashlib.md5()
    with open(fpath, "rb") as f:
        for chunk in iter(lambda: f.read(1024), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()
