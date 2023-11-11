FROM centos:7
SHELL ["/bin/bash", "-c"]

COPY ./fedora-infra-sigul.repo /etc/yum.repos.d/fedora-infra-sigul.repo

RUN yum install -y -q sigul

#RUN mkdir -p /w/workspace
