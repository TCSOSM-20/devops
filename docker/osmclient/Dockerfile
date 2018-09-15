FROM ubuntu:16.04

LABEL authors="Michael Marchetti"

RUN apt-get update && apt-get -y install curl software-properties-common

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} devops osmclient" && apt update

RUN apt-get update && apt-get -y install python \
    libcurl4-gnutls-dev libgnutls-dev osm-devops python-osmclient iputils-ping python-pip
RUN pip install python-magic pytest

ENV OSM_SOL005=True
ENV OSM_HOSTNAME=nbi:9999
ENV OSM_RO_HOSTNAME=ro:9090
