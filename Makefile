SHELL := /bin/bash
PATH  := $(PATH):.

all: setup certs status etcd kubes workers kubectl

# step 1
setup:
	setup.sh setup

# step 2
certs:
	cd certs && $(MAKE) 

copy:
	setup.sh copy

# step 3
etcd:
	setup.sh -s copy etcd 

# step 4
kubes:
	setup.sh kubes

# step 5
workers:
	setup.sh workers 

# step 6
kubectl:
	kcfg 

status:
	gcloud compute instances list

clean:
	setup.sh clean
	cd certs && $(MAKE) clean

verify:
	cd FILES && openssl x509 -in ca.pem -text -noout

.PHONY: all certs copy setup clean etcd kubes workers kubectl verify status

