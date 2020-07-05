# Copyright 2019 ETSI
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

FROM ubuntu:16.04

RUN apt-get update && apt-get install -y npm git python-pip nginx supervisor curl software-properties-common libmysqlclient-dev mysql-client
RUN ln -s /usr/bin/nodejs /usr/bin/node
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseEIGHT-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing
ARG LWUI_VERSION

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} LW-UI" && apt-get update

RUN apt-get install -y osm-lightui${LWUI_VERSION} && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/share/osm-lightui
RUN npm install
RUN mv node_modules ./static
RUN pip install -r requirements.txt
RUN pip install uwsgi
RUN cp /usr/share/osm-lightui/nginx-app.conf /etc/nginx/sites-available/default
RUN cp /usr/share/osm-lightui/supervisor-app.conf /etc/supervisor/conf.d/

# delete the copy of the database inside the container (if exists)
RUN rm -f db.sqlite3

ENV DJANGO_ENV=prod
ENV OSM_SERVER=nbi
# ENV OSMUI_SQL_DATABASE_URI=mysql://root:secret@mysql:3306/lwui
RUN python manage.py collectstatic --noinput
RUN chmod +x /usr/share/osm-lightui/entrypoint.sh

EXPOSE 80

HEALTHCHECK --start-period=130s --interval=10s --timeout=5s --retries=12 \
  CMD curl --silent --fail localhost:80 || exit 1

CMD ["/usr/share/osm-lightui/entrypoint.sh"]
