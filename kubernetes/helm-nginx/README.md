# Nginx Ingress controller on IBM Cloud

It contains a reference implementation for deploying a custom QSC enabled Nginx ingress controller in IBM cloud

## Prerequisites

* Helm3
* IBM cloud CLI
* Kubectl configured to the Kubernetes cluster in IBM cloud

### Helm Configuration

Configuration for values.yaml in 'qsc-nginx' directory

The following table lists the configurable parameters of the Qsc-nginx chart and their default values.

| Parameter                | Description             | Default        |
| ------------------------ | ----------------------- | -------------- |
| `imageCredentials.registry` | Registry for the image. image credentials info that will be used to create an image pull secret | `"de.icr.io/qsc-ingress-test-registry"` |
| `imageCredentials.username` | Username for accessing the registry | `"iamapikey"` |
| `imageCredentials.password` | Password | `"PasswordGoesHere"` |
| `imageCredentials.email` | Email | `"temp@.ibm.com"` |
| `client.image.repository` | Info required for testing the qsc setup using a qsc enabled curl client. repository info for the qsc enabled curl client | `"docker.io/qscingresspoc/qsc_curl"` |
| `client.image.tag` | Tag to use | `"latest"` |
| `client.image.pullPolicy` | Pull policy | `"Always"` |
| `backend.replicaCount` | No. of replicas for the backend deployment | `3` |
| `backend.image.repository` | Repository info for the sample backend | `"docker.io/qscingresspoc/custom_backend"` |
| `backend.image.tag` | Tag to use | `"latest"` |
| `backend.image.pullPolicy` | Pull policy | `"Always"` |
| `backend.nameOverride` | Used to set the label 'app.kubernetes.io/name' for the backend. if left empty, the default chart name will be used | `""` |
| `backend.fullnameOverride` | Used to set the name of the backend deployment and service. | `"custom-backend"` |
| `backend.serviceAccount.create` | Specifies whether a service account should be created | `true` |
| `backend.serviceAccount.name` | The name of the service account to use. if not set and create is true, a name is generated using the fullname template | `""` |
| `backend.podSecurityContext` | Pod security context | `{}` |
| `backend.securityContext` |  | `{}` |
| `backend.service.type` | Service type | `"ClusterIP"` |
| `backend.service.port` | Port where the service is exposed | `80` |
| `backend.nodeSelector` | Node selector information | `{}` |
| `backend.tolerations` |  | `[]` |
| `backend.affinity` |  | `{}` |
| `backend.resources` |  | `{}` |
| `ingress.enabled` | If set to true, the ingress resource will be deployed | `true` |
| `ingress.class` | Ingress class name used to target an ingress class and also deploy an ingress class resource with this name | `"nginx"` |
| `ingress.annotations.nginx.ingress.kubernetes.io/ssl-redirect` | Set to true to disable http access. only https access will be allowed if this is set to true | `"true"` |
| `ingress.hosts` | The hosts information to specify the host and the paths. this will be overridden if the 'deploy.sh' script is used for deployment and will point to the configured subdomain | `[{"host": "qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0001.eu-de.containers.appdomain.cloud", "paths": ["/"]}]` |
| `ingress.tls` | Tls related information. this will be overridden if the 'deploy.sh' script is used for deployment and will point to the configured subdomain and the secret name configured in the namespace | `[{"secretName": "qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0001", "hosts": ["qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0001.eu-de.containers.appdomain.cloud"]}]` |
| `ingressController.name` | This name should match the service name in the load-balancer chart. if 'deploy.sh' script is used, it will automatically ensure that this matches and overrides to match if necessary | `"helm-ingress-controller"` |
| `ingressController.image.repository` | repository info for the ingress controller | `"docker.io/qscingresspoc/qsc_nginx_ingress_controller"` |
| `ingressController.image.tag` | Tag to use | `"v0.40.2"` |
| `ingressController.image.pullPolicy` | Pull policy | `"Always"` |


## Wrapper script

The wrapper script 'deploy.sh' can be used to test and deploy a fully functional Nginx ingress controller with a sample backend in IBM cloud. It supports the following -

* Create / delete a namespace
* Install / uninstall a loadbalancer service for the ingress controller
* Configure or replace a DNS subdomain for the loadbalancer service
* Install / uninstall an ingress controller and a sample backend
* Tests to validate the ingress controller is functional and supports QSC

### Deployment

The script uses the values.yaml file in the 'load-balancer' and 'qsc-nginx' directory to deploy the necessary components in the cluster. 

The script supports the following flags -
```
    [-a ]
    List all helm releases in all namespaces
    If -n <namespace> is specified, only releases in that namespace is shown

    [-n <namespace> ] 
    Namespace to be used in the kubernetes cluster

    [-p <helm_release_name_prefix> ] 
    Release name prefix for the helm deployment
    <lb> deployment release will be named <helm_release_name_prefix>-lb
    <controller> deployment release will be named <helm_release_name_prefix>-controller

    [-c <cluster_name>]
    The name of the cluster being used in IBM cloud
    list the cluster name using 'ibmcloud ks cluster ls' and find the cluster being targetted

    [-s <loadbalancer_service_name>]
    The name of the loadbalancer_service backing the ingress controller deployment.
        To get all the loadbalancer services deployed, use -l flag
    This value will not have any effect if "-i lb" is used. In that case the value "service.name"
    in values.yaml in path "./load-balancer" will be used.
    If -i <lb> is not passed then the -s flag is required

    [-l ]
    Lists all the load-balancer service in a given namespace
        requires -n <namespace> to be specified

    [-i <lb> or <controller> or <namespace> ]
    Installs the mentioned components in the cluster.
        To install multiple components, use -i multiple times.
        Ex: "-i lb -i controller" will install the controller and the load-balancer
    <namespace> will install the namespace. The -n flag is required for this to work
    <lb> will install the loadbalancer and also set up a DNS subdomain with certs for TLS. 
            The -n flag and -c flag is required for this to work
    <controller> will install the controller. 
            The -n flag and -c flag is required for this to work. If -i <lb> is not passed then the -s flag is required

    [-u <lb> or <controller> or <namespace> ]
    Uninstalls the mentioned components in the cluster.
        To uninstall multiple components, use -u multiple times.
        Ex: "-u lb -u controller" will uninstall the controller and the load-balancer
    <namespace> will uninstall the namespace. The -n flag is required for this to work
    <lb> will uninstall the loadbalancer. The -p flag and -n flag is required for this to work
    <controller> will uninstall the controller. The -p flag and -n flag is required for this to work

    [-g]
    Get all subdomain mapping with loadbalancer
    requires -c <cluster_name> to be specified

    [-t]
    Test the controller deployment
    requires -p <helm_release_name_prefix> and -n <namespace>

    [-r <subdomain>]
    Replace subdomain with loadbalancer address
        To find the existing subdomains execute this script with -g
    This requires the -c <cluster_name> to be specified

    [-h  prints help message]

```

## Example Usage

### 1. Install the loadbalancer, create a DNS subdomain and deploy the ingress controller along with a backend and the ingress resource

```
./deploy.sh  -i lb -i namespace -i controller -c qsc-ingress-cluster -n helm-nginx-qsc -p qsc-nginx-release
```

The following actions are performed in this order

* Create a namespace "helm-nginx-qsc" in the kubernetes cluster
* Deploy the loadbalancer service for the Nginx ingress controller in that namespace
* Set up a DNS subdomain for the loadbalancer service and get the certs and keys for the subdomain
* Deploy the Nginx ingress controller, default backend, sample backend and the ingress resource
  * When deploying the ingress controller and the ingress, the following values in the 'qsc-nginx/values.yaml' file will be overridden
    * *ingress.hosts* to use the DNS subdomain and path set to default "/"
    * *ingress.tls* to set the secret name to what was configured during DNS subdomain setup and hosts to DNS subdomain
    * *ingressController.name* to what was configured as the loadbalancer service name

### 2. Uninstall the ingress controller, ingress resource and the backend deployment

```
./deploy.sh  -u controller -c qsc-ingress-cluster -n helm-nginx-qsc -p qsc-nginx-release
```

### 3. Install only the ingress controller, ingress resource and the backend deployment

This is useful in scenarios where the ingress controller needs to be modified or executed with different arguments but does not require a change for the load balancer service or the DNS subdomain. It is recommended in such situations to not re-deploy the load-balancer service. Re-deploying the load-balancer service will result in a new external loadbalancer host and then a new DNS subdomain will need to be configured or existing DNS sub domain replaced to map to the newly deployed ladbalancer service.

```
./deploy.sh  -i controller -c qsc-ingress-cluster -n helm-nginx-qsc -p qsc-nginx-release -s helm-ingress-controller
```
Sample output
```
 ------------------------- 
Installing controller & backend
----------------------------- 

LoadBalancer Service name: helm-ingress-controller
External LB Host: 5c465617-eu-de.lb.appdomain.cloud
DNS subdomain: qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0003.eu-de.containers.appdomain.cloud
Cert secret name: qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0003
NAME: qsc-nginx-release-controller
LAST DEPLOYED: Mon Nov  9 14:01:27 2020
NAMESPACE: helm-nginx-qsc
STATUS: deployed
REVISION: 1
NOTES:
1. Get to the application by accessing this URL:
  https://qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0003.eu-de.containers.appdomain.cloud/

```

Note that the previous command requires the '-s' flag to target the deployed load-balancer service such that the ingress-controller deployment can associate itself with the deployed load-balancer.

To list all the deployed load-balancer service use the '-l'  flag. Example -
```
./deploy.sh -l -n helm-nginx-qsc 
```
The output of this command can be used to specify the argument for the '-s' flag

### 4. Test that the ingress controller is QSC enabled and supports different key exchange mechanisms

```
./deploy.sh -t -n helm-nginx-qsc -p qsc-nginx-release
```

This will run tests against the ingress controller using different curves.
Sample output

```
 ------------------------- 
Testing deployment
----------------------------- 
Pod custom-backend-kyber1024-test pending
Pod custom-backend-kyber1024-test pending
Pod custom-backend-kyber1024-test pending
Pod custom-backend-kyber1024-test succeeded
Pod custom-backend-kyber512-test pending
Pod custom-backend-kyber512-test pending
Pod custom-backend-kyber512-test pending
Pod custom-backend-kyber512-test succeeded
Pod custom-backend-prime256-kyber512-test pending
Pod custom-backend-prime256-kyber512-test pending
Pod custom-backend-prime256-kyber512-test pending
Pod custom-backend-prime256-kyber512-test succeeded
Pod custom-backend-prime256v1-test pending
Pod custom-backend-prime256v1-test pending
Pod custom-backend-prime256v1-test pending
Pod custom-backend-prime256v1-test succeeded
Pod custom-backend-test-connection pending
Pod custom-backend-test-connection pending
Pod custom-backend-test-connection pending
Pod custom-backend-test-connection succeeded
Pod custom-backend-x25519-test pending
Pod custom-backend-x25519-test pending
Pod custom-backend-x25519-test pending
Pod custom-backend-x25519-test succeeded
NAME: test-release-controller
LAST DEPLOYED: Sat Nov  7 11:35:29 2020
NAMESPACE: helm-qsc
STATUS: deployed
REVISION: 1
TEST SUITE:     custom-backend-x25519-test
Last Started:   Mon Nov  9 14:17:24 2020
Last Completed: Mon Nov  9 14:17:26 2020
Phase:          Succeeded
TEST SUITE:     custom-backend-kyber1024-test
Last Started:   Mon Nov  9 14:17:13 2020
Last Completed: Mon Nov  9 14:17:15 2020
Phase:          Succeeded
TEST SUITE:     custom-backend-kyber512-test
Last Started:   Mon Nov  9 14:17:15 2020
Last Completed: Mon Nov  9 14:17:17 2020
Phase:          Succeeded
TEST SUITE:     custom-backend-prime256-kyber512-test
Last Started:   Mon Nov  9 14:17:17 2020
Last Completed: Mon Nov  9 14:17:19 2020
Phase:          Succeeded
TEST SUITE:     custom-backend-prime256v1-test
Last Started:   Mon Nov  9 14:17:19 2020
Last Completed: Mon Nov  9 14:17:21 2020
Phase:          Succeeded
TEST SUITE:     custom-backend-test-connection
Last Started:   Mon Nov  9 14:17:21 2020
Last Completed: Mon Nov  9 14:17:24 2020
Phase:          Succeeded
NOTES:
1. Get to the application by accessing this URL:
  https://qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0003.eu-de.containers.appdomain.cloud/

```

### 5. Install all the components but do not create a new DNS subdomain

```
./deploy.sh  -i lb  -i controller -c qsc-ingress-cluster -n helm-nginx-qsc -p qsc-nginx-release -r qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0002.eu-de.containers.appdomain.cloud
```

This will first install a load-balancer service. Instead of creating a new DNS subdomain for the load-balancer it will reconfigure the existing subdomain '*qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0002.eu-de.containers.appdomain.cloud*' to point to the deployed loadbalancer.

> Note that replacing an existing subdomain with a new load-balancer will take a long time to synchronize and therefore you may experience "cannot resolve host" error until the synchronization is complete. During this period all/some tests (mentioned in 4.) may fail

> Also note that replacing an existing subdomain will work only if the secrets for the subdomain is in the same namespace as that of the loadbalancer and the ingress controller

The previous command requires the '-r' flag with the existing subdomain to replace as its argument. To get all existing subdomains and the namespace of the secrets, run the following commad

```
./deploy.sh -g -c qsc-ingress-cluster 
```

Sample output

```
-------------------------
DNS sub-domains
-------------------------
OK
Subdomain                                                                                    Load Balancer Hostname              SSL Cert Status   SSL Cert Secret Name                                        Secret Namespace   
qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0000.eu-de.containers.appdomain.cloud   7e035ba8-eu-de.lb.appdomain.cloud   created           qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0000   default   
qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0001.eu-de.containers.appdomain.cloud   b9767a58-eu-de.lb.appdomain.cloud   created           qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0001   helm-nginx-qsc   
qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0002.eu-de.containers.appdomain.cloud   4fde18de-eu-de.lb.appdomain.cloud   created           qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0002   helm-qsc   
qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0003.eu-de.containers.appdomain.cloud   5c465617-eu-de.lb.appdomain.cloud   created           qsc-ingress-cluster-d465a2b8669424cc1f37658bec09acda-0003   helm-haproxy-qsc   

```
### 6. Get all the releases and the namespaces of deployment

```
./deploy.sh -a 
```

sample output

```
 ------------------------- 
Deployed releases
----------------------------- 
NAME                      	NAMESPACE       	REVISION	UPDATED                                	STATUS  	CHART                       APP VERSION
haproxy-release-controller	helm-haproxy-qsc	1       	2020-11-09 14:01:27.134125705 +0100 CET	deployed	qsc-nginx-0.1.0             0.1.0      
haproxy-release-lb        	helm-haproxy-qsc	1       	2020-11-07 13:24:46.541345558 +0100 CET	deployed	ibm-cloud-loadbalancer-0.1.00.1.0      
test-release-controller   	helm-qsc        	1       	2020-11-07 11:35:29.974308015 +0100 CET	deployed	qsc-nginx-0.1.0             0.1.0      
test-release-lb           	helm-qsc        	1       	2020-11-07 01:18:09.200142078 +0100 CET	deployed	ibm-cloud-loadbalancer-0.1.00.1        
```

This is useful to get the values for the '-n' flag and and '-p' flag in the script when targetting existing deployments.
* '-n' flag is the value under the "NAMESPACE" column. Example "helm-haproxy-qsc"
* '-p' flag is the prefix value for the release. Under the column "NAME", we see all the release names. For releases that were managed by the 'deploy.sh' script, there will either be a suffix '-lb' or '-controller'. The argument for the '-p' flag is the prefix name without this suffix. Example "haproxy-release" 