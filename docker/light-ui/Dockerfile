FROM ubuntu:16.04

RUN apt-get update && apt-get install -y npm git python-pip nginx supervisor curl software-properties-common libmysqlclient-dev mysql-client
RUN npm install -g bower
RUN ln -s /usr/bin/nodejs /usr/bin/node
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing
ARG LWUI_VERSION

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} LW-UI" && apt-get update

RUN apt-get install -y osm-lightui${LWUI_VERSION} && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/share/osm-lightui
RUN bower install --allow-root
RUN pip install -r requirements.txt
RUN pip install uwsgi
RUN cp /usr/share/osm-lightui/nginx-app.conf /etc/nginx/sites-available/default
RUN cp /usr/share/osm-lightui/supervisor-app.conf /etc/supervisor/conf.d/

# delete the copy of the database inside the container (if exists)
RUN rm -f db.sqlite3

ENV DJANGO_ENV=prod
RUN python manage.py makemigrations authosm
RUN python manage.py migrate
RUN python manage.py collectstatic --noinput


EXPOSE 80

HEALTHCHECK --start-period=130s --interval=10s --timeout=5s --retries=12 \
  CMD curl --silent --fail localhost:80 || exit 1

CMD ["supervisord", "-n"]
