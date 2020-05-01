# Copyright 2020 Arctos Labs Scandinavia AB
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM ubuntu:18.04

LABEL authors="Lars-Göran Magnusson"

RUN apt-get --yes update \
 && apt-get --yes install git python python-pip python3 python3-pip libmysqlclient-dev libssl-dev libffi-dev \
 && apt-get --yes install mysql-client curl software-properties-common libgl1-mesa-glx \
 && pip3 install pip==9.0.3

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} PLA common" && apt update

ARG PLA_VERSION
ARG COMMON_VERSION

RUN apt-get --yes update  && apt-get -y install python3-osm-common${COMMON_VERSION} python3-osm-pla${PLA_VERSION}

COPY scripts/ scripts/

ENV OSMPLA_MESSAGE_DRIVER kafka
ENV OSMPLA_MESSAGE_HOST kafka
ENV OSMPLA_MESSAGE_PORT 9092

ENV OSMPLA_DATABASE_DRIVER mongo
ENV OSMPLA_DATABASE_URI mongodb://mongo:27017

ENV OSMPLA_SQL_DATABASE_URI sqlite:///pla_sqlite.db

ENV OSMPLA_GLOBAL_LOG_LEVEL INFO

ENV FZNEXEC "/entry_data/fzn-exec"
ENV PATH "/minizinc/bin:${PATH}"
ENV LD_LIBRARY_PATH "/minizinc/lib:${LD_LIBRARY_PATH}"

# No healtcheck yet...
#HEALTHCHECK --start-period=120s --interval=10s --timeout=5s --retries=5 \
#  CMD osm-pla-healthcheck || exit 1

CMD /bin/bash scripts/start.sh
