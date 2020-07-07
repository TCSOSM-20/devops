<!-- #   Copyright 2020 Canonical Ltd.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License. -->

# NG-UI Charm

## How to deploy

```bash
juju deploy . # cs:~charmed-osm/ng-ui --channel edge
juju relate ng-ui nbi-k8s
```

## How to expose the NG-UI through ingress

```bash
juju config ng-ui juju-external-hostname=ng.<k8s_worker_ip>.xip.io
juju expose ng-ui
```

> Note: The <k8s_worker_ip> is the IP of the K8s worker node. With microk8s, you can see the IP with `microk8s.config`. It is usually the IP of your host machine.

## How to scale

```bash
    juju scale-application ng-ui 3
```

## How to use certificates

Generate your own certificate if you don't have one already:

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl_certificate.key -out ssl_certificate.crt
sudo chown $USER:$USER ssl_certificate.key
juju config ng-ui ssl_certificate=`cat ssl_certificate.crt | base64 -w 0`
juju config ng-ui ssl_certificate_key=`cat ssl_certificate.key | base64 -w 0`
```

## Config Examples

```bash
juju config ng-ui image=opensourcemano/ng-ui:<tag>
juju config ng-ui port=80
juju config server_name=<name>
juju config client_max_body_size=25M
```
