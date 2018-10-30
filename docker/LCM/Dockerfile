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

RUN apt-get update && apt-get install -y git make python3 \
    python3-pip python3-pymongo python3-yaml python3-aiohttp \
    python3-all python3-setuptools \
    python3-bitarray python3-regex python3-lxml dh-python wget tox \
    python3-cffi \
    && pip3 install pip==9.0.3 \
    && pip3 install -U aiokafka pyang lxml six enum34 \
    && pip3 install websockets==4.0.1 \
    && pip3 install requests

# packages needed for N2VC because deb dependencies are not fine
RUN pip3 install  'macaroonbakery>=1.1,<2.0' 'pyRFC3339>=1.0,<2.0' \
      'pyyaml>=3.0,<4.0' 'theblues>=0.3.8,<1.0' 'websockets>=4.0,<5.0' \
      'paramiko'   # PyNaCl
# 
# RUN git clone https://osm.etsi.org/gerrit/osm/N2VC.git \
#     && cd N2VC \
#     && cd modules/libjuju && python3 setup.py develop && cd ../.. \
#     && pip3 install -U -r requirements.txt

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
ENV OSMLCM_DATABASE_HOST   mongo
ENV OSMLCM_DATABASE_PORT   27017
ENV OSMLCM_STORAGE_DRIVER  local
ENV OSMLCM_STORAGE_PATH    /app/storage

# message
ENV OSMLCM_MESSAGE_DRIVER  kafka
ENV OSMLCM_MESSAGE_HOST    kafka
ENV OSMLCM_MESSAGE_PORT    9092

HEALTHCHECK --interval=30s --timeout=140s --retries=1 \
  CMD python3 /usr/lib/python3/dist-packages/osm_lcm/lcm.py --health-check || exit 1


# Run app.py when the container launches
CMD ["python3", "/usr/lib/python3/dist-packages/osm_lcm/lcm.py"]
