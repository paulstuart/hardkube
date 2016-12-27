FROM pstuart/alpine:latest

MAINTAINER Paul Stuart <pauleyphonic@gmail.com>

RUN wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 && \
    chmod +x cfssl_linux-amd64 && \
    mv cfssl_linux-amd64 /usr/local/bin/cfssl

RUN wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 && \
    chmod +x cfssljson_linux-amd64 && \
    mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

COPY gencert /usr/local/bin/

CMD ["/usr/local/bin/gencert"]

