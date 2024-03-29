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

# This creates osm/NBI docker from local NBI source code

FROM ubuntu:18.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install curl software-properties-common

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y git python3 python3-jsonschema \
    python3-pymongo python3-yaml python3-pip python3-keystoneclient \
    && pip3 install -U pip \
    && python3 -m pip install aiokafka aiohttp cherrypy==18.1.2 pyangbind keystoneauth1 \
    && mkdir -p /app/storage/kafka && mkdir -p /app/log

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} NBI IM common" && apt update

ARG NBI_VERSION
ARG COMMON_VERSION
ARG IM_VERSION

RUN apt-get update && apt-get -y install python3-osm-nbi${NBI_VERSION} python3-osm-common${COMMON_VERSION} python3-osm-im${IM_VERSION}

# Set the working directory to /app
WORKDIR /app/osm_nbi

EXPOSE 9999

RUN cp -R /usr/lib/python3/dist-packages/osm_nbi/html_public /app/osm_nbi/html_public
RUN cp /usr/lib/python3/dist-packages/osm_nbi/nbi.cfg /app/osm_nbi/
RUN cp -R /usr/lib/python3/dist-packages/osm_nbi/http /app/osm_nbi/

LABEL Maintainer="alfonso.tiernosepulveda@telefonica.com" \
      Description="This implements a north bound interface for OSM" \
      Version="1.0" \
      Author="Alfonso Tierno"

# Used for local storage
VOLUME /app/storage
# Used for logs
VOLUME /app/log

# The following ENV can be added with "docker run -e xxx' to configure
# server
ENV OSMNBI_SOCKET_HOST     0.0.0.0
ENV OSMNBI_SOCKET_PORT     9999
ENV OSMNBI_SERVER_SSL_CERTIFICATE               /app/osm_nbi/http/cert.pem
ENV OSMNBI_SERVER_SSL_PRIVATE_KEY               /app/osm_nbi/http/privkey.pem
# storage
ENV OSMNBI_STORAGE_PATH    /app/storage
# database
ENV OSMNBI_DATABASE_DRIVER mongo
ENV OSMNBI_DATABASE_URI   mongodb://mongo:27017
#ENV OSMNBI_DATABASE_HOST   mongo
#ENV OSMNBI_DATABASE_PORT   27017

# web
ENV OSMNBI_STATIC_DIR      /app/osm_nbi/html_public
# message
ENV OSMNBI_MESSAGE_DRIVER  kafka
ENV OSMNBI_MESSAGE_HOST    kafka
ENV OSMNBI_MESSAGE_PORT    9092
# logs
ENV OSMNBI_LOG_FILE        /app/log/nbi.log
ENV OSMNBI_LOG_LEVEL       DEBUG
# authentication
ENV OSMNBI_AUTHENTICATION_BACKEND               internal
#ENV OSMNBI_AUTHENTICATION_BACKEND               keystone
#ENV OSMNBI_AUTHENTICATION_AUTH_URL              keystone
#ENV OSMNBI_AUTHENTICATION_AUTH_PORT             5000
#ENV OSMNBI_AUTHENTICATION_USER_DOMAIN_NAME      default
#ENV OSMNBI_AUTHENTICATION_PROJECT_DOMAIN_NAME   default
#ENV OSMNBI_AUTHENTICATION_SERVICE_USERNAME      nbi
#ENV OSMNBI_AUTHENTICATION_SERVICE_PASSWORD      nbi
#ENV OSMNBI_AUTHENTICATION_SERVICE_PROJECT       service
#prometheus
ENV OSMNBI_PROMETHEUS_HOST                      prometheus
ENV OSMNBI_PROMETHEUS_PORT                      9090

HEALTHCHECK --start-period=120s --interval=10s --timeout=5s --retries=5 \
  CMD curl -k https://localhost:9999/osm/ | grep Welcome || exit 1

# Run app.py when the container launches
CMD python3 -m osm_nbi.nbi

