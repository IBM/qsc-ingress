#!/bin/bash

#set -x -e

LB_HELM_PATH="load-balancer"
INGRESS_HELM_PATH="qsc-haproxy"

create_namespace() {
  if [ -n "$1" ]; then
    kubectl create namespace $1
  fi
}

uninstall_namespace() {
  if [ -n "$1" ]; then
    kubectl delete namespace $1
  fi
}

# $1 is the namespace
# $2 is the release-name to uninstall
uninstall_release() {
  if [ $# -ne 2 ]; then
    echo -e "2 arguments required for uninstall_release"
    exit 1
  fi
  declare namespace=$1
  declare release_name=$2

  helm uninstall -n "$namespace" "$release_name"
}

# $1 is the namespace
# $2 is the release-name for the load-balancer
install_lb() {
  if [ $# -ne 2 ]; then
    echo -e "2 arguments required for install_lb"
    exit 1
  fi

  declare namespace=$1
  declare release_name=$2

  helm install --wait -n "$namespace" \
    "$release_name" ${LB_HELM_PATH}
}

# $1 is the namespace
# $2 is the release-name for the controller
# $3 is the service name
# $4 is the dns_entry_subdomain
# $5 is the dns_cert_secret
install_controller() {
  if [ $# -ne 5 ]; then
    echo -e "5 arguments required for install controller"
    exit 1
  fi

  declare namespace=$1
  declare release_name=$2
  declare service_name=$3
  declare dns_entry_subdomain=$4
  declare dns_cert_secret=$5

  helm install --wait -n ${namespace} \
    --set ingress.hosts[0].host=${dns_entry_subdomain} \
    --set ingress.hosts[0].paths={/} \
    --set ingress.tls[0].secretName=${dns_cert_secret} \
    --set ingress.tls[0].hosts={${dns_entry_subdomain}} \
    --set ingressController.name=${service_name} \
    ${release_name} ${INGRESS_HELM_PATH}

}

# Sets $service_name
get_lb_service_name_host() {
  if [ "$is_install_lb" == "true" ]; then
    service_name=$(awk '/service/{flag=1} flag && /name:/{print $NF;flag=""}' ${LB_HELM_PATH}/values.yaml)
  elif [ -n "$input_service_name" ]; then
    service_name=$input_service_name
  else
    echo -e "-s <service_name> is required if -i <lb> is not provided. \n"
    echo -e "Run the script with -l flag to list all loadbalancer service names"
    exit 1
  fi

  echo LoadBalancer Service name: "$service_name"
}

# $1 is the namespace
# $2 is the service name
#
# Sets $external_lb_host
get_external_lb_host() {
  if [ $# -ne 2 ]; then
    echo -e "2 arguments required for get_external_lb_host"
    exit 1
  fi

  declare namespace=$1
  declare service_name=$2

  external_lb_host=$(kubectl describe svc "$service_name" --namespace "$namespace" | grep "LoadBalancer Ingress:" | awk '{print $3}')
  while [ -z "$external_lb_host" ]; do
    echo "Waiting for load-balancer service to get ready; please wait..."
    external_lb_host=$(kubectl describe svc "$service_name" --namespace "$namespace" | grep "LoadBalancer Ingress:" | awk '{print $3}')
    sleep 2
  done

  echo External LB Host: "$external_lb_host"
}

# $1 is the namespace
# $2 is the clustername
# $3 is the external_lb_host
deploy_dns_lb() {

  if [ $# -ne 3 ]; then
    echo -e "3 arguments required for deploy_dns_lb"
    exit 1
  fi

  declare namespace=$1
  declare cluster_name=$2
  declare external_lb_host=$3

  ibmcloud ks nlb-dns create vpc-gen2 --cluster "$cluster_name" --lb-host "$external_lb_host" --type public \
    --secret-namespace "$namespace"

  dns_entry_status=$(ibmcloud ks nlb-dns ls --cluster "$cluster_name" | grep "$external_lb_host" | grep created)
  echo "Waiting for SSL cert to be created. This can take upto 10 mins"
  while [ -z "$dns_entry_status" ]; do
    echo "Waiting for SSL cert to be created. "
    dns_entry_status=$(ibmcloud ks nlb-dns ls --cluster "$cluster_name" | grep "$external_lb_host" | grep created)
    sleep 5
  done
}

# $1 is the clustername
get_dns_lb() {
  if [ $# -ne 1 ]; then
    echo -e "1 argument required for get_dns_lb"
    exit 1
  fi

  declare cluster_name=$1
  ibmcloud ks nlb-dns ls --cluster "$cluster_name"
}

# $1 is the clustername
# $2 is the external_lb_host
#
# Sets $dns_entry_subdomain
# Sets $dns_cert_secret
get_dns_info_for_lb_host() {

  if [ $# -ne 2 ]; then
    echo -e "2 arguments required for get_dns_info_for_lb_host"
    exit 1
  fi

  declare cluster_name=$1
  declare external_lb_host=$2

  dns_entry_subdomain=$(ibmcloud ks nlb-dns ls --cluster "$cluster_name" | grep "$external_lb_host" | awk '{print $1}')
  dns_cert_secret=$(ibmcloud ks nlb-dns ls --cluster "$cluster_name" | grep "$external_lb_host" | awk '{print $4}')
  echo "DNS subdomain: $dns_entry_subdomain"
  echo "Cert secret name: $dns_cert_secret"
}

# $1 is the subdomain name
# $2 is the clustername
# $3 is the external_lb_host
# $4 is the namespace
replace_dns_lb() {

  if [ $# -ne 4 ]; then
    echo -e "4 arguments required for replace_dns_lb"
    exit 1
  fi

  declare subdomain_name=$1
  declare cluster_name=$2
  declare external_lb_host=$3
  declare namespace=$4

  subdomain_secret_namespace=$(ibmcloud ks nlb-dns ls --cluster "$cluster_name" | grep "$subdomain_name" | awk '{print $5}')

  if [[ "$subdomain_secret_namespace" != "$namespace" ]]; then
    echo -e "[ERROR] cannot replace subdomain because the subdomain secret is in a different namespace. Exiting..."
    echo -e "subdomain secret namespace: $subdomain_secret_namespace"
    echo -e "requested namespace: $namespace"
    exit 1
  fi

  ibmcloud ks nlb-dns replace --cluster "$cluster_name" --lb-host "$external_lb_host" --nlb-subdomain "$subdomain_name"
}

validate_namespace() {
  if [ -z "$namespace" ]; then
    echo "Incorrect usage. Namespace (-n flag) should be specified."
    echo "<usage> $0 -h for help"
    exit 1
  fi
}

validate_release_name() {
  if [ -z "$release_name" ]; then
    echo "Incorrect usage. Release name prefix (-p flag) should be specified."
    echo "<usage> $0 -h for help"
    exit 1
  fi
}

usage() {
  echo "\
    Usage:  $0  
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
    This value will not have any effect if \"-i lb\" is used. In that case the value \"service.name\"
    in values.yaml in path \"./${LB_HELM_PATH}\" will be used.
    If -i <lb> is not passed then the -s flag is required

    [-l ]
    Lists all the load-balancer service in a given namespace
      requires -n <namespace> to be specified

    [-i <lb> or <controller> or <namespace> ]
    Installs the mentioned components in the cluster.
        To install multiple components, use -i multiple times.
        Ex: \"-i lb -i controller\" will install the controller and the load-balancer
    <namespace> will install the namespace. The -n flag is required for this to work
    <lb> will install the loadbalancer and also set up a DNS subdomain with certs for TLS. 
         The -n flag and -c flag is required for this to work
    <controller> will install the controller. 
         The -n flag and -c flag is required for this to work. If -i <lb> is not passed then the -s flag is required

    [-u <lb> or <controller> or <namespace> ]
    Uninstalls the mentioned components in the cluster.
        To uninstall multiple components, use -u multiple times.
        Ex: \"-u lb -u controller\" will uninstall the controller and the load-balancer
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
    "
}

print_demarcation() {
  printf "\n\n %s \n" "-------------------------"
  echo "$1"
  printf "%s \n" "-----------------------------"
}

while getopts ":aln:hp:i:u:c:s:r:gt" opt; do
  case $opt in
  a)
    is_list_release=true
    ;;
  l)
    is_list_lb=true
    ;;
  t)
    is_test=true
    ;;
  g)
    is_get_dns_lb=true
    ;;
  s)
    is_input_service_name=true
    input_service_name=$OPTARG
    ;;
  c)
    is_cluster_name=true
    cluster_name=$OPTARG
    ;;
  i)
    if [ $OPTARG == "lb" ]; then
      is_install_lb=true
    elif [ $OPTARG == "namespace" ]; then
      is_install_namespace=true
    elif [ $OPTARG == "controller" ]; then
      is_install_controller=true
    fi
    ;;
  u)
    if [ $OPTARG == "lb" ]; then
      is_uninstall_lb=true
    elif [ $OPTARG == "namespace" ]; then
      is_uninstall_namespace=true
    elif [ $OPTARG == "controller" ]; then
      is_uninstall_controller=true
    fi
    ;;
  p)
    is_release_name=true
    release_name=$OPTARG
    release_name_controller="$release_name-controller"
    release_name_lb="$release_name-lb"
    ;;
  r)
    is_replace_subdomain=true
    subdomain_name=$OPTARG
    ;;
  n)
    is_namespace=true
    namespace=$OPTARG
    ;;
  h)
    usage
    exit 1
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    usage
    exit 1
    ;;
  :)
    echo "Option -$OPTARG requires an argument." >&2
    usage
    exit 1
    ;;
  esac
done

if [[ -n $is_list_release ]]; then
  print_demarcation "Deployed releases"
  if [ -z "$namespace" ]; then
    helm list --all-namespaces
  else
    helm list -n "$namespace"
  fi
fi

if [[ -n $is_list_lb ]]; then
  print_demarcation "Loadbalancer service names"
  validate_namespace
  kubectl get service --namespace $namespace | grep LoadBalancer | awk '{print $1}'
fi

if [[ -n $is_get_dns_lb ]]; then
  if [[ -n $is_cluster_name ]]; then
    print_demarcation "DNS sub-domains"
    get_dns_lb $cluster_name
    exit 0
  else
    echo -e "Incorrect usage. Cluster name (-c flag) should be provided when -g is used"
    exit 1
  fi
fi

if [[ -n $is_install_namespace ]]; then
  print_demarcation "Creating namespace ${namespace}" 
  validate_namespace
  create_namespace $namespace
fi

if [[ -n $is_install_lb ]]; then
  if [[ -n $is_cluster_name ]]; then
    print_demarcation "Installing loadbalancer service"
    validate_namespace
    validate_release_name
    install_lb $namespace $release_name_lb
    get_lb_service_name_host
    get_external_lb_host $namespace $service_name

    if [[ -n $is_replace_subdomain ]]; then
      echo -e "\nRemapping DNS subdomain \"$subdomain_name\" to loadbalancer service ..."
      replace_dns_lb $subdomain_name $cluster_name $external_lb_host $namespace
    else
      echo -e "\nSetting up a DNS subdomain for the loadbalancer service ..."
      deploy_dns_lb $namespace $cluster_name $external_lb_host
    fi
  else
    echo -e "Incorrect usage. Cluster name (-c flag) should be provided when -i <lb> is used"
    exit 1
  fi
fi

if [[ -n $is_install_controller ]]; then
  if [[ -n $is_cluster_name ]]; then
    print_demarcation "Installing controller & backend"
    echo 
    validate_namespace
    validate_release_name
    get_lb_service_name_host
    get_external_lb_host $namespace $service_name
    get_dns_info_for_lb_host $cluster_name $external_lb_host

    install_controller $namespace $release_name_controller $service_name $dns_entry_subdomain $dns_cert_secret
  else
    echo -e "Incorrect usage. Cluster name (-c flag) should be provided when -i <controller> is used"
    exit 1
  fi
fi

if [[ -n $is_test ]]; then
  print_demarcation "Testing deployment"
  validate_namespace
  validate_release_name
  helm test -n "$namespace" "$release_name_controller"
fi

if [[ -n $is_uninstall_controller ]]; then
    print_demarcation "Uninstalling controller"
    validate_namespace
    validate_release_name
    uninstall_release "$namespace" "$release_name_controller"
fi

if [[ -n $is_uninstall_lb ]]; then
    print_demarcation "Uninstalling loadbalancer"
    validate_namespace
    validate_release_name
    uninstall_release "$namespace" "$release_name_lb"
fi

if [[ -n $is_uninstall_namespace ]]; then
    print_demarcation "Uninstalling namespace"
    validate_namespace
    uninstall_namespace "$namespace"
fi
