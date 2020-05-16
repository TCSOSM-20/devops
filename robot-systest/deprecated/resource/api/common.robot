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
# 1. Feature 7829: Jayant Madavi, Mrityunjay Yadav : MY00514913@techmahindra.com
##


*** Variables ***
&{HEADERS}     Content-Type=application/json       Accept=application/json
&{data}        username=admin      password=admin      project-id=admin
@{success_status_code_list}     200     201     202    204

${descriptor_content_type_gzip}   application/gzip

${auth_token_uri}   /osm/admin/v1/tokens

${get_all_vnfd_uri}   /osm/vnfpkgm/v1/vnf_packages
${create_vnfd_uri}   /osm/vnfpkgm/v1/vnf_packages_content
${delete_vnfd_uri}   /osm/vnfpkgm/v1/vnf_packages

${get_all_nsd_uri}   /osm/nsd/v1/ns_descriptors
${create_nsd_uri}   /osm/nsd/v1/ns_descriptors_content
${delete_nsd_uri}   /osm/nsd/v1/ns_descriptors

${base_ns_uri}   /osm/nslcm/v1/ns_instances_content
${create_ns_uri}   /osm/nslcm/v1/ns_instances_content

${create_vim_uri}   /osm/admin/v1/vim_accounts
