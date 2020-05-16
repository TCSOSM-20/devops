#!/usr/bin/python
# Copyright 2020 Canonical Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#     Unless required by applicable law or agreed to in writing, software
#     distributed under the License is distributed on an "AS IS" BASIS,
#     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#     See the License for the specific language governing permissions and
#     limitations under the License.

from charms.reactive import RelationBase
from charms.reactive import hook
from charms.reactive import scopes


class OsmROProvides(RelationBase):
    scope = scopes.GLOBAL

    @hook("{provides:osm-ro}-relation-joined")
    def joined(self):
        self.set_state("{relation_name}.joined")

    @hook("{provides:osm-ro}-relation-changed")
    def changed(self):
        self.set_state("{relation_name}.ready")

    @hook("{provides:osm-ro}-relation-{broken,departed}")
    def broken_departed(self):
        self.remove_state("{relation_name}.ready")
        self.remove_state("{relation_name}.joined")

    @hook("{provides:osm-ro}-relation-broken")
    def broken(self):
        self.set_state("{relation_name}.removed")

    def send_connection(self, host, port=9090):
        conv = self.conversation()
        conv.set_remote("host", host)
        conv.set_remote("port", port)
