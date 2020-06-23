# Copyright 2020 ETSI
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

RUN apt-get update && apt-get install -y curl xz-utils gnupg2 \
    && apt-get update && apt-get install -y apt-transport-https software-properties-common \
    && curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - \
    && echo "deb https://deb.nodesource.com/node_10.x xenial main" | tee -a /etc/apt/sources.list.d/nodesource.list \
    && echo "deb-src https://deb.nodesource.com/node_10.x xenial main" | tee -a /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && apt-get install -y nginx

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseSEVEN-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing
ARG NGUI_VERSION

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} NG-UI" && apt-get update

RUN apt-get install -y osm-ngui${NGUI_VERSION} && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/share/osm-ngui
RUN npm install

# Building app.
RUN npm run build
RUN cp /usr/share/osm-ngui/nginx/nginx.conf /etc/nginx/sites-available/default

# Removing the Nginx default page.
RUN rm -rf /usr/share/nginx/html/*

# Copying angular build to Nginx default page.
RUN cp -r /usr/share/osm-ngui/dist/osm/* /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --start-period=130s --interval=10s --timeout=5s --retries=12 \
  CMD curl --silent --fail localhost:80 || exit 1

# Starting server.
CMD ["nginx", "-g", "daemon off;"]

