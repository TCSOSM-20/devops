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


from osmclient import client
from robot.api import logger
import json


class ClientLib:
    def __init__(self, host="127.0.0.1", user=None, password=None, project=None):

        kwargs = {}
        if user is not None:
            kwargs['user'] = user
        if password is not None:
            kwargs['password'] = password
        if project is not None:
            kwargs['project'] = project
        self.client = client.Client(host=host, sol005=True, **kwargs)

    def get_vim_list(self):
        resp = self.client.vim.list()
        logger.info('VIM List: {}'.format(resp))
        return json.dumps(resp)

    def create_vim_account(self, name, vim_type, user, password, auth_url, tenant, desc='', config=None):
        vim_access = {}
        if config is not None:
            vim_access['config'] = config
        vim_access['vim-type'] = vim_type
        vim_access['vim-username'] = user
        vim_access['vim-password'] = password
        vim_access['vim-url'] = auth_url
        vim_access['vim-tenant-name'] = tenant
        vim_access['description'] = desc

        resp = self.client.vim.create(name, vim_access)
        logger.info('Create VIM Account: {}'.format(resp))
        return json.dumps(resp)

    def delete_vim_account(self, name):
        resp = self.client.vim.delete(name)
        return json.dumps(resp)

    def get_vnfd_list(self):
        resp = self.client.vnfd.list()
        logger.info('VNF Descriptor List: {}'.format(resp))
        return json.dumps(resp)

    def get_nsd_list(self):
        resp = self.client.nsd.list()
        logger.info('NS Descriptor List: {}'.format(resp))
        return json.dumps(resp)
