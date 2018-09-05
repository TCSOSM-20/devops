from ubuntu:xenial

MAINTAINER Gennadiy Dubina <gennadiy.dubina@dataat.com>; Alfonso Tierno <alfonso.tiernosepulveda@telefoncia.com>

RUN apt-get update && apt-get -y install curl software-properties-common

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} RO IM common openvim" && apt update

RUN apt-get update && apt-get install -y python-setuptools python-wheel mysql-client python-bitarray
RUN apt-get update && apt-get install -y python-osm-ro python-osm-im

RUN mkdir -p /bin/RO

COPY scripts/ /bin/RO

VOLUME /opt/openmano/logs

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

CMD /bin/RO/start.sh
