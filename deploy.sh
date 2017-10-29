#!/bin/bash
#### S2I Build Issue ####
# must specify a user that is numeric and within the range of allowed users
# https://github.com/openshift/source-to-image/issues/279#issuecomment-136649898
#
# [root@ruo91 ~]# oadm policy add-scc-to-user privileged [user] -n [project name] -z builder
#
# - Example
# User    : admin
# Project : tensorflow
# [root@ruo91 ~]# oadm policy add-scc-to-user privileged admin -n tensorflow -z builder
#
# [root@ruo91 ~]# oc get scc privileged -o yaml
# ....
# .......
# users:
# - system:serviceaccount:tensorflow:builder
# 

#### Docker Build & Push ####
docker build --rm -t docker-registry.default.svc:5000/openshift/tensorflow:latest-gpu .
docker push docker-registry.default.svc:5000/openshift/tensorflow:latest-gpu
