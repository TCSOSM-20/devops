# Copyright 2018 Whitestack, LLC
# *************************************************************

# This file is part of OSM Monitoring module
# All Rights Reserved to Whitestack, LLC

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at

#         http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# For those usages not covered by the Apache License, Version 2.0 please
# contact: bdiaz@whitestack.com or glavado@whitestack.com
##

FROM ubuntu:16.04

LABEL authors="Guillermo Calvino"

RUN apt-get update \
    && apt-get -y install curl \
                          software-properties-common \
                          git \
                          python \
                          python-pip \
                          python3 \
                          python3-pip \
                          libmysqlclient-dev \
                          libssl-dev \
                          libffi-dev \
                          mysql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install pip==9.0.3

RUN pip3 install  'macaroonbakery>=1.1,<2.0' 'pyRFC3339>=1.0,<2.0' \
      'pyyaml>=5.1.2' 'theblues>=0.3.8,<1.0' 'websockets>=4.0,<5.0' \
      'paramiko'   # PyNaCl

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

ARG MON_VERSION
ARG COMMON_VERSION
ARG N2VC_VERSION

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add - \
    && add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} MON N2VC common" \
    && apt update \
    && apt-get -y install python3-osm-common${COMMON_VERSION} \
                          python3-osm-mon${MON_VERSION} \
                          python3-n2vc${N2VC_VERSION}


RUN python3 -m pip install -U juju

COPY scripts/ scripts/

ENV OSMMON_MESSAGE_DRIVER kafka
ENV OSMMON_MESSAGE_HOST kafka
ENV OSMMON_MESSAGE_PORT 9092

ENV OSMMON_DATABASE_DRIVER mongo
ENV OSMMON_DATABASE_URI mongodb://mongo:27017

ENV OSMMON_SQL_DATABASE_URI sqlite:///mon_sqlite.db
ENV OSMMON_OPENSTACK_DEFAULT_GRANULARITY 300
ENV OSMMON_GLOBAL_REQUEST_TIMEOUT 10
ENV OSMMON_GLOBAL_LOGLEVEL INFO
ENV OSMMON_VCA_HOST localhost
ENV OSMMON_VCA_SECRET secret
ENV OSMMON_VCA_USER admin
ENV OSMMON_DATABASE_COMMONKEY changeme
ENV OSMMON_COLLECTOR_INTERVAL 30
ENV OSMMON_EVALUATOR_INTERVAL 30
ENV OSMMON_PROMETHEUS_URL http://prometheus:9090

EXPOSE 8000

HEALTHCHECK --start-period=120s --interval=10s --timeout=5s --retries=5 \
  CMD osm-mon-healthcheck || exit 1

CMD /bin/bash scripts/start.sh
