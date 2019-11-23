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

from ubuntu:18.04

MAINTAINER Gennadiy Dubina <gennadiy.dubina@dataat.com>; Alfonso Tierno <alfonso.tiernosepulveda@telefoncia.com>

RUN apt-get update && apt-get -y install curl software-properties-common git tox python3-pip \
    && python3 -m pip install --upgrade pip && python3 -m pip install pyangbind

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} RO IM common openvim" && apt-get update

ARG RO_VERSION
ARG IM_VERSION

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3-osm-ro${RO_VERSION} python3-osm-im${IM_VERSION} \
    python3-osm-roclient${RO_VERSION} \
    python3-osm-rosdn-tapi${RO_VERSION} python3-osm-rosdn-dynpac${RO_VERSION} python3-osm-rosdn-onosof${RO_VERSION} \
    python3-osm-rovim-vmware${RO_VERSION} python3-osm-rovim-openstack${RO_VERSION} \
    python3-osm-rovim-openvim${RO_VERSION} python3-osm-rovim-azure${RO_VERSION} \
    python3-osm-rovim-aws${RO_VERSION} python3-osm-rovim-fos${RO_VERSION} python3-osm-rovim-opennebula${RO_VERSION}
    # python3-osm-rosdn-floodlightof python3-osm-rosdn-odlof 


VOLUME /var/log/osm

EXPOSE 9090

# Two mysql databases are needed (DB and DB_OVIM). Can be hosted on same or separated containers
# These ENV must be provided
ENV RO_DB_HOST=""
ENV RO_DB_OVIM_HOST=""
    # if empty RO_DB_HOST is assumed

# These ENV should be provided first time for creating database. It will create and init only if empty!
ENV RO_DB_ROOT_PASSWORD=""
ENV RO_DB_OVIM_ROOT_PASSWORD=""
    # if empty RO_DB_ROOT_PASSWORD is assumed

# These ENV can be provided, but default values are ok
ENV RO_DB_USER=mano
ENV RO_DB_OVIM_USER=mano
ENV RO_DB_PASSWORD=manopw
ENV RO_DB_OVIM_PASSWORD=manopw
ENV RO_DB_PORT=3306
ENV RO_DB_OVIM_PORT=3306
ENV RO_DB_NAME=mano_db
ENV RO_DB_OVIM_NAME=mano_vim_db
ENV OPENMANO_TENANT=osm

HEALTHCHECK --start-period=130s --interval=10s --timeout=5s --retries=12 \
  CMD curl --silent --fail localhost:9090/openmano/tenants || exit 1
CMD /usr/bin/RO-start.sh

