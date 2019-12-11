<!--
Copyright 2019 Minsait - Indra S.A.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
Author: Jose Manuel Palacios (jmpalacios@minsait.com)
Author: Jose Antonio Martinez (jamartinezv@minsait.com)
-->

# Monitoring in Kubernetes based OSM

## Introduction

This implementation deploys a PM stack based on Prometheus Operator plus a series of exporters for monitoring the OSM nodes and third party software modules (Kafka, mongodb and mysql)

In a high level, it consists of two scripts that deploy/undeploy the required objects in a previously existing Kubernetes based OSM installation.
Those scripts use already existing and freely available software: Helm, Kubernetes Operator and a set of exporters and dashboards pretty much standard. Helm server part (tiller) and charts deployed depends on Kubernetes version 1.15.x. Charts versions are pre-configured in an installation script and can be easily changed.

As a result, there will be 3 folders in Grafana:

- Summary: with a quick view of the platform global status.
- OSM Third Party Modules: dashboards for MongoDB, MyslqDB and Kafka.
- Kubernetes cluster: dashboards for pods, namespaces, nodes, etc.

## Requirements

- Kubernetes 1.15.X
- OSM Kubernetes version Release 7

## Components

- Installs the helm client on the host where the script is run (if not already installed)
- Creates a service account in the k8s cluster to be used by tiller, with sufficient permissions to be able to deploy kubernetes objects.
- Installs the helm server part (tiller) and assigns to tiller the previously created service account (if not already installed)
- Creates a namespace (monitoring) where all the components that are part of the OSM deployment monitoring `pack` will be installed.
- Installs prometheus-operator using the `stable/prometheus-operator` chart which is located at the default helm repository (<https://kubernetes-charts.storage.googleapis.com/>). This installs a set of basic metrics for CPU, memory, etc. of hosts and pods. It also includes grafana and dashboards.
- Installs an exporter for mongodb using the `stable/prometheus-mongodb-exporter` chart, which is located at the default  helm repository (<https://kubernetes-charts.storage.googleapis.com/>).
- Adds a dashboard for mongodb to grafana through a local yaml file.
- Installs an exporter for mysql using the `stable/prometheus-mysql-exporter` chart which is located at the default helm repository (<https://kubernetes-charts.storage.googleapis.com/>).
- Adds a dashboard for mysql to grafana through a local yaml file.
- Installs an exporter for kafka using a custom-build helm chart with a deployment and its corresponding service and service monitor with local yaml files. We take the kafka exporter from <https://hub.docker.com/r/danielqsj/kafka-exporter>.
- Add a dashboard for kafka to grafana through a local yaml file.

## Versions

We use the following versions:

- PROMETHEUS_OPERATOR=6.18.0
- PROMETHEUS_MONGODB_EXPORTER=2.3.0
- PROMETHEUS_MYSQL_EXPORTER=0.5.1
- HELM_CLIENT=2.15.2

## Install

Note: This implementation is dependent on the Kubernetes OSM deployment, and the installation script must be executed AFTER the Kubernetes deployment has been completed. Notice that it is not applicable to the basic docker deployment.

```bash
usage: ./install_osm_k8s_monitoring.sh [OPTIONS]
Install OSM Monitoring
  OPTIONS
     -n <namespace>   :   use specified kubernetes namespace - default: monitoring
     -s <service_type>:   service type (ClusterIP|NodePort|LoadBalancer) - default: NodePort
     --debug          :   debug script
     --dump           :   dump arguments and versions
     -h / --help      :   print this help
```

## Uninstall

To uninstall the utility you must use the installation script.

```sh
./uninstall_osm_k8s_monitoring.sh
```

It will uninstall all components of this utility. To see the options type --help.

```sh
usage: ./uninstall_osm_k8s_monitoring.sh [OPTIONS]
Uninstall OSM Monitoring
  OPTIONS
     -n <namespace>:   use specified kubernetes namespace - default: monitoring
     --helm        :   uninstall tiller
     --debug       :   debug script
     -h / --help   :   print this help
```

## Access to Grafana Web Monitoring

To view the WEB with the different dashboards it is necessary to connect to the service "grafana" installed with this utility
and view the NodePort that uses. If the utility is installed with the default namespace "monitoring" you must type this:

```sh
kubectl get all --namespace monitoring
```

You must see the NodePort (greater than 30000) that uses the grafana service and type in your WEB browser:

```sh
  http://<ip_your_osm_host>:<nodeport>
```
  
- Username: admin
- Password: prom-operator
