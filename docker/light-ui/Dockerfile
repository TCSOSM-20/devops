FROM ubuntu:16.04

WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y npm git python-pip nginx supervisor
RUN npm install -g bower
RUN git clone https://osm.etsi.org/gerrit/osm/LW-UI /usr/src/app

RUN ln -s /usr/bin/nodejs /usr/bin/node
RUN bower install --allow-root

RUN pip install -r requirements.txt
RUN pip install uwsgi
#
RUN echo "daemon off;" >> /etc/nginx/nginx.conf
RUN cp /usr/src/app/nginx-app.conf /etc/nginx/sites-available/default
RUN cp /usr/src/app/supervisor-app.conf /etc/supervisor/conf.d/

# delete the copy of the database inside the container (if exists)
RUN rm -f db.sqlite3

ENV DJANGO_ENV=prod
RUN python manage.py makemigrations authosm
RUN python manage.py migrate
RUN python manage.py collectstatic --noinput


EXPOSE 80

CMD ["supervisord", "-n"]
