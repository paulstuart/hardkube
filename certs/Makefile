#SHELL := /bin/bash

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-certificate-authority.md

all: docker certs

certs:
	docker run -it -v $(PWD)/FILES:/mnt/shared \
		-e KUBERNETES_PUBLIC_ADDRESS=$(shell gcloud compute addresses describe kubernetes --format 'value(address)') \
		pstuart/certs

docker:
	docker build -t pstuart/certs .

clean:
	rm -f FILES/*.pem
	rm -f FILES/*.csr
	rm -f FILES/kubernetes-csr.json

verify:
	cd FILES && openssl x509 -in ca.pem -text -noout

.PHONY: all certs clean docker verify

