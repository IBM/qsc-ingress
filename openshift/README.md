## HAproxy-based custom router for ROKS
The custom router for OpenShift is implemented in a RedHat UBI v8.2 image and is based on the HAproxy router provided by the OKD v4.5.0 (August 2020) distribution. However, the basic HAproxy app was replaced by its version v2.2.2, and the underlaying OpenSSL libraries were replaced by their QSC-enabled v1.1.1g equivalents provided by the Open Quantum Safe project built from verified sources. The custom OpenShift router was successfully tested in a HA deployment in the IBM Cloud with OpenShift version 4.4.20. 

### Build the image

```
#local installation path setting (replace with your settings)
workdir=/data/ingress/openshift

# Prerequisites
# (A) You need an OpenShift Cluster on the IBM Cloud
# Note: The requires a standard plan (read: lite plan does not work) for COS
# We're using a 2 node, 2 AZ cluster with Openshift v4.4.17 (for which the worker nodes automatically got v4.418_1516)
# (B) Install oc command on your linux box (if not already available)
cd $workdir
oc_version=4.5
rm -rf oc
wget https://mirror.openshift.com/pub/openshift-v4/clients/oc/$oc_version/linux/oc.tar.gz
tar -xzf oc.tar.gz
rm oc.tar.gz

#local installation path setting
workdir=/data/ingress/openshift

# IBM Cloud settings (replace with your settings)
registry_path=de.icr.io
ingress_registry=qsc-ingress-test-registry
ingress_repo=router_qsc

# Image version tag
controller_version=qsc_v1.0.1

# build qsc router image
cd $workdir
sudo docker build -f Dockerfile -t $ingress_repo:$controller_version .
 
# prepare the image
cd $work_dir
sudo docker tag $ingress_repo:$controller_version $registry_path/$ingress_registry/$ingress_repo:$controller_version

```

### Deployment
```
#0) Prerequisites
#Environment variables: (replace with your settings)
my_cluster='openshift-cluster-v4.4.17'
my_namespace='custom-router-openshift'
workdir=/data/ingress/openshift
cd $workdir

#1) Create a new project
./oc new-project $my_namespace --description="QSC Router based on HAproxy" --display-name="qsc-openshift-router"
./oc project qsc-openshift-router 

#1) Create a namespace and an image pull secret for that namespace
cp deploy-qsc-openshift-router-namespace.yaml current_deployment.yaml 
sed -i "s/@@my_namespace@@/$my_namespace/" current_deployment.yaml
./oc apply -f current_deployment.yaml
rm current_deployment.yaml
# Create an image pull secret for that namespace
./oc --namespace $my_namespace create secret docker-registry qsc-openshift-router-image-pull-secret --docker-server=de.icr.io/qsc-ingress-test-registry --docker-username=iamapikey --docker-password=<my_password> --docker-email=<my_email>

#2) Create a (public or private) load-balancer service; default is public
cp deploy-qsc-openshift-router-loadbalancer-service.yaml current_deployment.yaml 
sed -i "s/@@my_namespace@@/$my_namespace/" current_deployment.yaml
./oc apply -f current_deployment.yaml
rm current_deployment.yaml

#3) Wait for the service to be ready and get the 'LoadBalancer Ingress' address
LB_Host_Adress=$(./oc describe svc qsc-openshift-router -n $my_namespace | grep 'LoadBalancer Ingress:' | cut -d' ' -f3- | tr -d '[:space:]'); echo $LB_Host_Adress
while [ -z $LB_Host_Adress]; do echo "Waiting for service to get ready; please wait....$LB_Host_Adress"; sleep 2; LB_Host_Adress=$(./oc describe svc qsc-openshift-router -n $my_namespace | grep 'LoadBalancer Ingress:' | cut -d' ' -f3- | tr -d '[:space:]'); done
echo "LB host address = $LB_Host_Adress"
./oc describe svc qsc-openshift-router -n $my_namespace 

#4) Create an external application load-balancer
ibmcloud ks nlb-dns create vpc-gen2 --cluster $my_cluster --lb-host $LB_Host_Adress --type public --secret-namespace $my_namespace -q
# Wait for LB to become ready (including certificates) and then get address and certificate names
External_LB_Info=''
External_LB_Info=$(ibmcloud ks nlb-dns ls --cluster $my_cluster | grep "$LB_Host_Adress" | grep "created")
while [ -z $External_LB_Info ]; do echo "Waiting for external ALB to get ready; please wait...."; sleep 2; External_LB_Info=$(ibmcloud ks nlb-dns ls --cluster $my_cluster | grep $LB_Host_Adress | grep "created"); done
External_LB_address=$(echo $External_LB_Info | cut -d' ' -f1)
#External_LB_CertSecretName=$(echo $External_LB_Info | cut -d'created' -f1- | tr -d '[:space:]' | cut -d' ' -f1)
External_LB_CertSecretName=$(echo $External_LB_Info | cut -d ' ' -f4 | tr -d '[:space:]')
echo "LB host address = $LB_Host_Adress"
#echo "External LB info line = $External_LB_Info"
echo "External ALB address = $External_LB_address"
echo "External ALB SSL Cert Secret Name = $External_LB_CertSecretName"
ibmcloud ks nlb-dns ls --cluster $my_cluster -q

#5) Deploy the HAproxy router controller
cp deploy-qsc-openshift-router-controller.yaml current_deployment.yaml 
sed -i "s/@@my_namespace@@/$my_namespace/" current_deployment.yaml
sed -i "s/@@External_LB_CertSecretName@@/$External_LB_CertSecretName/" current_deployment.yaml
/data/ingress/openshift/oc apply -f current_deployment.yaml
rm current_deployment.yaml

#6) Deploy a dummy backend including its ingress
#cp deploy-nginx-backend.yaml current_deployment.yaml 
#sed -i "s/@@my_namespace@@/$my_namespace/" current_deployment.yaml
#sed -i "s/@@External_LB_address@@/$External_LB_address/" current_deployment.yaml
#sed -i "s/@@External_LB_CertSecretName@@/$External_LB_CertSecretName/" current_deployment.yaml
#./oc apply -f current_deployment.yaml
#rm current_deployment.yaml
#./oc get ingress -o wide -n $my_namespace
#./oc describe ingress -n $my_namespace nginx-backend-dummy-webserver-ingress
cp deploy-echo-server.yaml current_deployment.yaml 
sed -i "s/@@my_namespace@@/$my_namespace/" current_deployment.yaml
sed -i "s/@@External_LB_address@@/$External_LB_address/" current_deployment.yaml
sed -i "s/@@External_LB_CertSecretName@@/$External_LB_CertSecretName/" current_deployment.yaml
./oc apply -f current_deployment.yaml
rm current_deployment.yaml
./oc get ingress -o wide -n $my_namespace
./oc describe ingress -n $my_namespace nginx-backend-dummy-webserver-ingress

```

