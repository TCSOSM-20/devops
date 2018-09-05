# This creates osm/NBI docker from local NBI source code

FROM ubuntu:16.04

RUN apt-get update && apt-get -y install curl software-properties-common

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} NBI IM common" && apt update

RUN apt-get -y install python3-osm-nbi python3-osm-common python3-osm-im

# Set the working directory to /app
WORKDIR /app/osm_nbi

RUN apt-get update && apt-get install -y git python3 python3-jsonschema \
    python3-pymongo python3-yaml python3-pip \
    && pip3 install pip==9.0.3 \
    && pip3 install aiokafka cherrypy pyangbind \
    && mkdir -p /app/storage/kafka && mkdir -p /app/log

EXPOSE 9999

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
# storage
ENV OSMNBI_STORAGE_PATH    /app/storage
# database
ENV OSMNBI_DATABASE_DRIVER mongo
ENV OSMNBI_DATABASE_HOST   mongo
ENV OSMNBI_DATABASE_PORT   27017
# web
ENV OSMNBI_STATIC_DIR      /usr/lib/python3/dist-packages/osm_nbi/html_public
# logs
ENV OSMNBI_LOG_FILE        /app/log
ENV OSMNBI_LOG_LEVEL       DEBUG
# message
ENV OSMNBI_MESSAGE_DRIVER  kafka
ENV OSMNBI_MESSAGE_HOST    kafka
ENV OSMNBI_MESSAGE_PORT    9092
# logs
ENV OSMNBI_LOG_FILE        /app/log/nbi.log
ENV OSMNBI_LOG_LEVEL       DEBUG

# Run app.py when the container launches
CMD ["python3", "/usr/lib/python3/dist-packages/osm_nbi/nbi.py"]
