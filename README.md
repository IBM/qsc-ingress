# qsc-ingress
QSC-enabled [K8S ingress controller](./kubernetes/nginx) &amp; [QSC-enabled OpenShift router](./openshift): 

**Terminate QSC TLSv1.3 connections at ingress/router of a cluster in the IBM Cloud**

## Introduction
While TLS connections today are well suited to protect access to the IBM Cloud via the Internet, any attacker able to access the network traffic could store it and easily decrypt it once a quantum computer is available. This can be done by decrypting the phase of the TLS connection establishment where the two parties agree on a session key with the help of some form of Diffie-Hellman (DH) key exchange. 

To counter this threat, it is becoming more and more important to use quantum-safe-crypto (QSC) key exchange mechanisms (KEM) like [KYBER](https://pq-crystals.org/kyber/index.shtml) during the DH session key establishment of a TLS connection. While KYBER is still in the last round of NIST standardization, hybrid curves can be used to ensure that the security of a TLS connection is not worse than today, but nevertheless benefit from hardness against future attacks from quantum computers. 

To enable clients with QSC protected access to clusters in the [IBM Cloud](https://www.ibm.com/cloud), IBM Research implemented a custom ingress controller for [Kubernetes](https://cloud.ibm.com/docs/containers?topic=containers-getting-started) and a custom router for [OpenShift](https://cloud.ibm.com/docs/openshift?topic=openshift-getting-started) which both enable QSC access to the related clusters in the IBM Cloud. With that, clients can access their clusters benefitting from QSC protected TLS session key establishment, while not having to change anything for the services inside their clusters.  

The [custom ingress controller for k8s](./kubernetes/nginx) and [custom router for ROKS](./openshift) respectively are terminating TLSv1.3 connections from the internet and feature full backward compatibility for non-QSC operation, enable network connections to use QSC curves for session key establishment, and also offer the possibility to use hybrid QSC/non-QSC session key establishment for staged transition to QSC operation during the time NIST standardization is not yet complete.   

The custom ingress controller and custom router can be deployed **in parallel** to the 'standard' components. This allows evaluation of the QSC functionality in a non-disruptive way by maintaining non-QSC access to the clusters.   

![Overview](./images/Overview.jpg?raw=true)
PoC configuration: QSC-enabled custom ingress for k8s (left) and custom router for ROKS (right)

**Important note:** While the above figures show an external LB, we use this building-block only to benefit from the automatic provisioning of certificates. In a real world application, such certificates would be established for the ingress controller/router directly, which makes the extra LB redundant.

In addition, a QSC-enabled version of a [cURL client](./client/curl) was implemented such that HTTP requests can be issued to the clusters using a TLSv1.3 connection with legacy curves, QSC curves, and hybrid legacy/QSC curve combinations for the TLS session key establishment. 

Last-not-least, a performance analysis was done to measure the latency penalties (or the lack thereof) for a TLS connection establishment using a selected number of different curves in comparison with the well-established legacy X25519 curve.

## Prerequisites
The QSC ingress controller and ROKS router is intendend for persons very familiar with the IBM Cloud. 

The deployment files are assuming that you have a k8s and/or ROKS cluster in the IBM CLoud with at least two nodes each for high-availability. If your cloud setup differs from that, you might need to adapt the deployment files. 

The build of the Docker images was done on an Ubuntu 18.04 Linux box, obviously with Docker installed. 

**Disclaimer:** All information here is provided as-is with no warranty. In particular, as the QSC algorithms are not (yet) NIST certified, use in production environment is not supported nor recommended. 

## QSC-enabled K8s Custom Ingress 
The [custom ingress controller](./kubernetes/nginx) is implemented in an Alpine v3.11 image and is based on the community NGINX ingress controller (v3.6.0, controller version 0.40.2), but the underlaying OpenSSL v1.1.1g libraries were replaced by their QSC-enabled equivalents provided by the [Open Quantum Safe project](https://github.com/open-quantum-safe/openssl). All components were built from verified sources. The custom ingress controller was successfully tested in a HA deployment in the IBM Cloud with Kubernetes version 1.18.9.

## QSC-enabled Router for OpenShift
The [custom router for OpenShift ROKS](./openshift) is implemented in a RedHat UBI v8.2 image and is based on the HAproxy router provided by the OKD v4.5.0 (August 2020) distribution. However, the basic HAproxy app was replaced by its version v2.2.2, and the underlaying OpenSSL libraries were replaced by their QSC-enabled v1.1.1g equivalents provided by the [Open Quantum Safe project](https://github.com/open-quantum-safe/openssl) built from verified sources. The custom OpenShift router was successfully tested in a HA deployment in the IBM Cloud with OpenShift version 4.4.20.

## Dummy backend service
In both the Kubernetes as well as the OpenShift cluster, a dummy web-server was used to mimic an intra-cluster service entity to which requests from the Internet are routed via the ingress controller or router respectively. The TLS connection in any case is terminated by the ingress controller or router respectively, the connection to the dummy service entity inside the cluster was done in plain HTTP, protected by a VPC network and namespace insulation.

## QSC Client
A [cURL client](./client/curl) was implemented inside an Ubuntu v20.04LTS image. The cURL v7.72.0 uses nghttp2 v 1.41.0 to enable HTTP2. It was patched to enable specification of curves on the command line and uses the OpenSSL v 1.1.1g QSC-enabled version from the Open Quantum Safe project. Further patches were applied to display (in cURL verbose mode, using the -v flag) the curve name used for session key establishment as well as the type of certificate used to sign the TLS handshake messages. The latter also enables to verify any tests against QSC certificates, e,g. Dilithium. This to simplify the verification that indeed QSC curves (and also QSC certificates at a later point in time) are used during TLS session key establishment. 

Special care has been taken to separate the QSC-enabled cURL version from any legacy cURL version inside the image. For example, custom library symbols were used, such that any application leveraging the libcurl.so libraires could – at the same time – use the legacy cURL code as well as the QSC-enabled cURL code.

## Deployment
While we encurage users to build images from sources and use the provided deployment yaml files to fully understand how things are working, [Helm charts](https://helm.sh/docs/) for [NGINX-based](https://github.com/IBM/qsc-ingress/tree/main/kubernetes/helm-nginx) and [HAproxy-based](https://github.com/IBM/qsc-ingress/tree/main/kubernetes/helm-haproxy) k8s custom ingress controllers are provided for ease of use, along with the related pre-built images on (rate limited) [Dockerhub](https://hub.docker.com/) for [NGINX-based](https://hub.docker.com/r/qscingresspoc/qsc_nginx_ingress_controller/tags) and [HAproxy-based](https://hub.docker.com/r/qscingresspoc/qsc_haproxy_ingress_controller/tags) k8s ingress cotrollers, a [QSC cURL client](https://hub.docker.com/r/qscingresspoc/qsc_curl/tags) and a [custom backend](https://hub.docker.com/r/qscingresspoc/custom_backend/tags).

## Performance Testing
A load tester was implemented inside an Ubuntu v20.04LTS image for [performance testing](./performance-testing). It is based on the h2load tool (which is part of the nghttp2 v1.41.0 project), with a QSC-enabled OpenSSL v1.1.1g which provides the TLS connectivity. The h2load tool provides information about the time required for TLS connection establishment. The goal of the load testing was to determine any latency penalty when establishing a TLSv1.3 connection in comparison with the legacy X25519 curve. 

## Recommended ciphers, curves and certificates
The table below provides recommendations for ciphers, curves and certificates to be used for different levels of desired security. It should be noticed that as long as online-attacks from quantum computers are not part of the threat model, traditional RSA/ECC certificates are sufficiently protecting the authenticity of TLS connections. 

![RecommendationsForUsage](./images/RecommendedCiphersCurvesCertificates.jpg?raw=true)

## Copyrights
The various components used are subject to copyrights of thier respective owners. 
