## NGINX-based custom ingress controller for k8s
The custom ingress controller is implemented in an Alpine v3.11 image and is based on the community NGINX ingress controller (v3.6.0, controller version 0.40.2), but the underlaying OpenSSL v1.1.1g libraries were replaced by their QSC-enabled equivalents provided by the Open Quantum Safe project. All components were built from verified sources. The custom ingress controller was successfully tested in a HA deployment in the IBM Cloud with Kubernetes version 1.18.9.

See also [here](https://cloud.ibm.com/docs/containers?topic=containers-ingress-user_managed) and [here](https://cloud.ibm.com/docs/containers?topic=containers-ingress-user_managed#user_managed_vpc)

### Build the image

```
#local installation path setting
work_dir=<my_directory>/NGINX

# IBM Cloud settings (replace with your settings)
registry_path=de.icr.io
ingress_registry=qsc-ingress-test-registry
ingress_repo=ingress_qsc

# get community ingress controller
controller_version=v0.40.2
ingress_nginx_version=3.6.0
active_version=$ingress_nginx_version
cd $work_dir
rm -rf ingress-nginx
git clone --branch controller-$controller_version https://github.com/kubernetes/ingress-nginx.git
#git clone --branch ingress-nginx-$ingress_nginx_version https://github.com/kubernetes/ingress-nginx.git

# OPTIONAL: build base image from sources
ingress_base=ingress_base
cd $work_dir/ingress-nginx/images/nginx/rootfs
sudo docker build -f Dockerfile -t $ingress_base:$active_version .

# build qsc ingress controller (use either of the two options A || B, but not both)
cd $work_dir
# (A) Using the community image
sudo docker build -f Dockerfile -t $ingress_repo:$active_version  .
# OR 
# (B) Using the locally built image from above
sudo docker build -f Dockerfile --build-arg BASE_IMAGE=$ingress_base:$active_version -t $ingress_repo:$active_version .

```

### Deployment
```
#0) Prerequisites
#Environment variables: 
my_cluster='qsc-ingress-eu-de-3-bx2.4x16'
my_namespace='nginx-ingress-private-namespace'
# Where are the yamls to find 
cd <my_directory>/NGINX

#1) Create a namespace and an image pull secret for that namespace
cp deploy-nginx-ingress-namespace.yaml current_deployment.yaml 
sed -i "s/@@my_namespace@@/$my_namespace/" current_deployment.yaml
kubectl apply -f current_deployment.yaml
rm current_deployment.yaml
# Create an image pull secret for that namespace
kubectl --namespace $my_namespace create secret docker-registry qsc-ingress-image-pull-secret --docker-server=de.icr.io/qsc-ingress-test-registry --docker-username=iamapikey --docker-password=<my_IAM_password> --docker-email=<my_email>

#2) Create a (public) load-balancer service
#loadbalancer_service_name="deploy-nginx-ingress-private-loadbalancer-service"
#cp deploy-nginx-ingress-loadbalancer-service.yaml current_deployment.yaml 
cp deploy-nginx-ingress-private-loadbalancer-service.yaml current_deployment.yaml 
sed -i "s/@@my_namespace@@/$my_namespace/" current_deployment.yaml
kubectl apply -f current_deployment.yaml
rm current_deployment.yaml
kubectl describe svc ingress-nginx-controller -n $my_namespace 

#3) Wait for the service to be ready and get the 'LoadBalancer Ingress' address
#LB_Host_Adress=$(kubectl describe svc ingress-nignx-loadbalancer-service -n $my_namespace | grep 'LoadBalancer Ingress:' | cut -d' ' -f3- | tr -d '[:space:]'); echo $LB_Host_Adress
LB_Host_Adress=$(kubectl describe svc ingress-nginx-controller -n $my_namespace | grep 'LoadBalancer Ingress:' | cut -d' ' -f3- | tr -d '[:space:]'); echo $LB_Host_Adress
#while [ -z $LB_Host_Adress]; do echo "Waiting for service to get ready; please wait....$LB_Host_Adress"; sleep 2; LB_Host_Adress=$(kubectl describe svc ingress-nignx-loadbalancer-service -n $my_namespace | grep 'LoadBalancer Ingress:' | cut -d' ' -f3- | tr -d '[:space:]'); done
while [ -z $LB_Host_Adress]; do echo "Waiting for service to get ready; please wait....$LB_Host_Adress"; sleep 2; LB_Host_Adress=$(kubectl describe svc ingress-nginx-controller -n $my_namespace | grep 'LoadBalancer Ingress:' | cut -d' ' -f3- | tr -d '[:space:]'); done
echo "LB host address = $LB_Host_Adress"
#kubectl describe svc ingress-nignx-loadbalancer-service -n $my_namespace 
kubectl describe svc ingress-nginx-controller -n $my_namespace 

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

#5) Deploy the NGINX ingress controller
kubectl delete IngressClass ingress-nginx-controller
cp deploy-qsc-nginx-ingress-controller.yaml current_deployment.yaml 
sed -i "s/@@my_namespace@@/$my_namespace/" current_deployment.yaml
sed -i "s/@@External_LB_CertSecretName@@/$External_LB_CertSecretName/" current_deployment.yaml
kubectl apply -f current_deployment.yaml
rm current_deployment.yaml

#6) Deploy a dummy Nginx-based webserver including its ingress
cp deploy-nginx-backend.yaml current_deployment.yaml 
sed -i "s/@@my_namespace@@/$my_namespace/" current_deployment.yaml
sed -i "s/@@External_LB_address@@/$External_LB_address/" current_deployment.yaml
sed -i "s/@@External_LB_CertSecretName@@/$External_LB_CertSecretName/" current_deployment.yaml
kubectl apply -f current_deployment.yaml
rm current_deployment.yaml
kubectl get ingress -o wide -n $my_namespace
kubectl describe ingress -n $my_namespace nginx-backend-dummy-webserver-ingress

```
