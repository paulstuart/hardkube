#!/bin/bash

#
# Step 1: Initial infrastructure (GCP)
#
# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/01-infrastructure-gcp.md
#

# Set the region and zone to us-central1:

export GCP_REGION=us-central1
export GCP_ZONE=us-central1-f

export GCP_BOOTDISK=200GB
export GCP_IMAGE=ubuntu-1604-xenial-v20160921
export GCP_IMAGE_PROJECT=ubuntu-os-cloud
export GCP_MACHINE_TYPE=n1-standard-1

# Create a Kubernetes network

export NETWORK=kubernetes

clean() {
    echo
    echo deleting controllers
    for ctrl in controller{0,1,2} worker{0,1,2}
    do
        gcloud -q compute instances delete $ctrl &
    done
    wait

    # Clear Firewall Rules
    echo
    echo deleting firewall
    gcloud -q compute firewall-rules delete kubernetes-allow-icmp &
    gcloud -q compute firewall-rules delete kubernetes-allow-internal &
    gcloud -q compute firewall-rules delete kubernetes-allow-rdp &
    gcloud -q compute firewall-rules delete kubernetes-allow-ssh &
    gcloud -q compute firewall-rules delete kubernetes-allow-healthz &
    gcloud -q compute firewall-rules delete kubernetes-allow-api-server &
    wait

    echo
    echo deleting addresses
    gcloud -q compute addresses delete $NETWORK --region=$GCP_REGION

    echo
    echo deleting network
    gcloud -q compute networks subnets delete $NETWORK 
    gcloud -q compute networks delete $NETWORK 
}

# Virtual Machines

instance() {
    gcloud compute instances create $1 \
     --boot-disk-size $GCP_BOOTDISK \
     --can-ip-forward \
     --image $GCP_IMAGE \
     --image-project $GCP_IMAGE_PROJECT \
     --machine-type $GCP_MACHINE_TYPE \
     --private-network-ip $2 \
     --subnet $NETWORK
}

setup() {
    echo
    echo creating network
    gcloud compute networks create $NETWORK --mode custom

    # Create a subnet for the Kubernetes cluster:

    echo
    echo creating firewall
    gcloud compute networks subnets create $NETWORK \
      --network $NETWORK \
      --range 10.240.0.0/24

    gcloud compute firewall-rules create kubernetes-allow-icmp \
      --allow icmp \
      --network $NETWORK \
      --source-ranges 0.0.0.0/0 

    gcloud compute firewall-rules create kubernetes-allow-internal \
      --allow tcp:0-65535,udp:0-65535,icmp \
      --network $NETWORK \
      --source-ranges 10.240.0.0/24

    gcloud compute firewall-rules create kubernetes-allow-rdp \
      --allow tcp:3389 \
      --network $NETWORK \
      --source-ranges 0.0.0.0/0

    gcloud compute firewall-rules create kubernetes-allow-ssh \
      --allow tcp:22 \
      --network $NETWORK \
      --source-ranges 0.0.0.0/0

    gcloud compute firewall-rules create kubernetes-allow-healthz \
      --allow tcp:8080 \
      --network $NETWORK \
      --source-ranges 130.211.0.0/22

    gcloud compute firewall-rules create kubernetes-allow-api-server \
      --allow tcp:6443 \
      --network $NETWORK \
      --source-ranges 0.0.0.0/0

    gcloud compute firewall-rules list --filter "network=$NETWORK"

    # Create a public IP address that will be used by remote clients to connect to the Kubernetes control plane:

    echo
    echo creating network / addresses
    gcloud compute addresses create $NETWORK --region=$GCP_REGION
    gcloud compute addresses list $NETWORK

    # Kubernetes Controllers

    instance controller0 10.240.0.10 &
    instance controller1 10.240.0.11 &
    instance controller2 10.240.0.12 &
    wait

    # Kubernetes Workers

    instance worker0 10.240.0.20 &
    instance worker1 10.240.0.21 &
    instance worker2 10.240.0.22 &
    wait
}

list() {
    gcloud compute instances list
}

copy() {
    ETCD=$PWD/etcd_setup
    KUBE=$PWD/kube_setup
    WORKER=$PWD/worker_setup
    TOKEN=$PWD/token.csv
	cd certs/FILES
    KUBERNETES_HOSTS=(controller{0,1,2})
	for host in ${KUBERNETES_HOSTS[*]}; do
  		gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem $ETCD $KUBE $TOKEN ${host}:~/ &
	done
    KUBERNETES_HOSTS=(worker{0,1,2})
	for host in ${KUBERNETES_HOSTS[*]}; do
  		gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem $TOKEN $WORKER ${host}:~/ &
	done
    wait
}

etcd() {
    KUBERNETES_HOSTS=(controller{0,1,2})
	for host in ${KUBERNETES_HOSTS[*]}; do
        gcloud compute ssh $host -- sudo ./etcd_setup &
	done
    wait
}

kubes() {
    KUBERNETES_HOSTS=(controller{0,1,2})
	for host in ${KUBERNETES_HOSTS[*]}; do
        gcloud compute ssh $host -- sudo ./kube_setup &
	done
    wait
}

workers() {
    KUBERNETES_HOSTS=(worker{0,1,2})
	for host in ${KUBERNETES_HOSTS[*]}; do
        gcloud compute ssh $host -- sudo ./worker_setup &
	done
    wait
}

sys() {
    KUBERNETES_HOSTS=(controller{0,1,2})
	for host in ${KUBERNETES_HOSTS[*]}; do
        gcloud compute ssh $host -- sudo systemctl status kube-apiserver --no-pager &
	done
    wait
}

estatus() {
    KUBERNETES_HOSTS=(controller{0,1,2})
	for host in ${KUBERNETES_HOSTS[*]}; do
        gcloud compute ssh $host -- sudo systemctl status etcd --no-pager &
	done
    wait
}

checks() {
    gcloud compute http-health-checks create kube-apiserver-check \
      --description "Kubernetes API Server Health Check" \
      --port 8080 \
      --request-path /healthz

    gcloud compute target-pools create kubernetes-pool \
      --http-health-check=kube-apiserver-check

    gcloud compute target-pools add-instances kubernetes-pool \
      --instances controller0,controller1,controller2

    KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes \
      --format 'value(address)')

    gcloud compute forwarding-rules create kubernetes-rule \
      --address ${KUBERNETES_PUBLIC_ADDRESS} \
      --ports 6443 \
      --target-pool kubernetes-pool
}

configure() {
    copy
    etcd
    kubes
    workers
}

if [[ $1 == "-s" ]]; then
    shift
    gcloud -q config set compute/region $GCP_REGION
    gcloud -q config set compute/zone $GCP_ZONE
fi

while [[ -n $1 ]]
do
    case $1 in
        estatus|etcd|kubes|workers|checks|sys|controllers|list|clean|copy|setup|configure) ;;
        *) echo "usage: $0 <clean|copy|configure|setup>"; exit 1 ;;
    esac

    $1
    shift
done

