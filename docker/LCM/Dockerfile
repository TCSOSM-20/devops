##
# Copyright 2019 ETSI
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

########################################################################

# This creates som/LCM docker from from last stable package

FROM ubuntu:16.04

# Set the working directory to /app
WORKDIR /app/osm_lcm

# avoid extra information from packages
RUN echo 'path-exclude /usr/share/doc/*\n\
path-include /usr/share/doc/*/copyright\n\
path-exclude /usr/share/man/*\n\
path-exclude /usr/share/groff/*\n\
path-exclude /usr/share/info/*\n\
path-exclude /usr/share/lintian/*\n\
path-exclude /usr/share/linda/*\n'\
> /etc/dpkg/dpkg.cfg.d/01_nodoc && \
    echo  'APT::Install-Recommends "false";\n\
APT::AutoRemove::RecommendsImportant "false";\n\
APT::AutoRemove::SuggestsImportant "false";\n'\
> /etc/apt/apt.conf.d/99_norecommends

RUN apt-get update && apt-get -y install curl software-properties-common

RUN apt-get install -y git make python3 \
    python3-pip python3-pymongo python3-aiohttp \
    python3-all python3-setuptools openssh-client libffi-dev libssl-dev \
    python3-bitarray python3-regex python3-lxml dh-python wget tox \
    python3-cffi \
    && python3 -m pip install pip --upgrade \
    && python3 -m pip install -U aiokafka lxml six enum34 \
    && python3 -m pip install requests \
    && python3 -m pip install -U juju \
    && rm -rf /var/lib/apt/lists/*

# RUN git clone https://osm.etsi.org/gerrit/osm/N2VC.git \
#     && cd N2VC \
#     && cd modules/libjuju && python3 setup.py develop && cd ../.. \
#     && python3 -m pip install -U -r requirements.txt

RUN apt-get update && apt-get install -y curl \
    && apt-get update && apt-get install -y apt-transport-https \
    && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update && apt-get install -y kubectl

RUN curl https://get.helm.sh/helm-v2.15.2-linux-amd64.tar.gz --output helm-v2.15.2.tar.gz \
    && tar -zxvf helm-v2.15.2.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && rm -r linux-amd64/

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} LCM N2VC common" && apt update

ARG LCM_VERSION
ARG COMMON_VERSION
ARG N2VC_VERSION

RUN apt-get update && apt-get install -y python3-osm-lcm${LCM_VERSION} \
                                         python3-osm-common${COMMON_VERSION} \
                                         python3-n2vc${N2VC_VERSION} \
                                         && rm -rf /var/lib/apt/lists/*

EXPOSE 9999

LABEL Maintainer="alfonso.tiernosepulveda@telefonica.com" \
      Description="This implements life cycle management engine for OSM" \
      Version="1.0" \
      Author="Alfonso Tierno"

# Used for local storage
VOLUME /app/storage
# Used for logs
VOLUME /app/log

# The following ENV can be added with "docker run -e xxx' to configure LCM
ENV OSMLCM_RO_HOST         ro
ENV OSMLCM_RO_PORT         9090
ENV OSMLCM_RO_TENANT       osm

# VCA
ENV OSMLCM_VCA_HOST        vca
ENV OSMLCM_VCA_PORT:       17070
ENV OSMLCM_VCA_USER:       admin
ENV OSMLCM_VCA_SECRET:     secret

# database
ENV OSMLCM_DATABASE_DRIVER mongo
ENV OSMLCM_DATABASE_URI    mongodb://mongo:27017
#ENV OSMLCM_DATABASE_HOST    mongo
#ENV OSMLCM_DATABASE_PORT    27017


ENV OSMLCM_STORAGE_DRIVER  local
ENV OSMLCM_STORAGE_PATH    /app/storage

# message
ENV OSMLCM_MESSAGE_DRIVER  kafka
ENV OSMLCM_MESSAGE_HOST    kafka
ENV OSMLCM_MESSAGE_PORT    9092

# k8s
ENV OSMLCM_VCA_HELMPATH    /usr/local/bin/helm
ENV OSMLCM_VCA_KUBECTLPATH /usr/bin/kubectl

# logs
# ENV OSMLCM_GLOBAL_LOGFILE  /app/log/lcm.log
# ENV OSMLCM_GLOBAL_LOGLEVEL DEBUG

HEALTHCHECK --start-period=120s --interval=30s --timeout=30s --retries=1 \
  CMD python3 -m osm_lcm.lcm --health-check || exit 1


# Run app.py when the container launches
CMD python3 -m osm_lcm.lcm

