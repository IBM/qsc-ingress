## Overview
The [custom ingress controller](./nginx) is implemented in an Alpine v3.11 image and is based on the community NGINX ingress controller (v3.6.0, controller version 0.40.2), but the underlaying OpenSSL v1.1.1g libraries were replaced by their QSC-enabled equivalents provided by the Open Quantum Safe project. All components were built from verified sources. The custom ingress controller was successfully tested in a HA deployment in the IBM Cloud with Kubernetes version 1.18.9.

A HAproxy-based ingress controller will follow.

## Test setup

![Use Cases](../images/K8S_Overview.jpg?raw=true)


