#!/bin/bash

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes \
  --format 'value(address)')

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=certs/FILES/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

PASSWORD=$(awk -F',' '$2 == "admin" {print $1}' token.csv)

kubectl config set-credentials admin --token $PASSWORD

kubectl config set-context default-context \
  --cluster=kubernetes-the-hard-way \
  --user=admin

kubectl config use-context default-context

kubectl 
exit

kubectl get nodes 
exit

kubectl get nodes \
      --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address} {.spec.podCIDR} {"\n"}{end}'
exit

kubectl get componentstatuses

kubectl get nodes
