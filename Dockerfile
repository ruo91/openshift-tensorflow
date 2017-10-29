##################################################
# Title: OpenShift S2I - Google TensorFlow (GPU) #
# Date : 2017.10.29                              #
# Maintainer: Yongbok Kim (ruo91@yongbok.net)    #
##################################################

# Use the base images
FROM centos:centos7
LABEL maintainer="Yongbok Kim <ruo91@yongbok.net>"

#### OpenShift Builder ####
# Set the labels that are used for OpenShift to describe the builder image.
LABEL io.k8s.description="TensorFlow (GPU)" \
    io.k8s.display-name="tensorflow - latest-gpu" \
    io.openshift.tags="builder,tensorflow" \
    # this label tells s2i where to find its mandatory scripts
    # (run, assemble, save-artifacts)
    io.openshift.s2i.scripts-url="image:///opt/s2i"

#### Packages ####
#RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Base.repo \
# && sed -i 's/#baseurl\=http\:\/\/mirror.centos.org/baseurl\=http\:\/\/ftp.daumkakao.com/g' /etc/yum.repos.d/CentOS-Base.repo
RUN yum clean all && yum repolist && yum install -y nano net-tools curl epel-release

#### Work Directory ####
WORKDIR "/opt/notebooks"

#### Default PATH ####
ENV CUDA_HOME /usr/local/cuda
ENV TF_HOME $HOME/venvs/tensorflow/bin
ENV PATH $PATH:$TF_HOME:$CUDA_HOME

### CUDA Profile ####
#  For CUDA profiling, TensorFlow requires CUPTI.
ENV LD_LIBRARY_PATH /usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH

#### Nvidia Docker ####
LABEL com.nvidia.volumes.needed="nvidia_driver"

#### Nvidia Container Runtime ###
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV NVIDIA_REQUIRE_CUDA "cuda>=8.0"

#### NVIDIA CUDA Runtime ####
ENV CUDA_VERSION 8.0.61
LABEL com.nvidia.cuda.version="${CUDA_VERSION}"

RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

RUN NVIDIA_GPGKEY_SUM=d1be581509378368edeec8c1eb2958702feedf3bc3d17011adbf24efacce4ab5 && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/7fa2af80.pub | sed '/^Version/d' > /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA && \
    echo "$NVIDIA_GPGKEY_SUM  /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA" | sha256sum -c --strict -
COPY conf/repos/cuda.repo /etc/yum.repos.d/cuda.repo

ENV CUDA_PKG_VERSION 8-0-$CUDA_VERSION-1
RUN yum install -y \
        cuda-nvrtc-$CUDA_PKG_VERSION \
        cuda-nvgraph-$CUDA_PKG_VERSION \
        cuda-cusolver-$CUDA_PKG_VERSION \
        cuda-cublas-8-0-8.0.61.2-1 \
        cuda-cufft-$CUDA_PKG_VERSION \
        cuda-curand-$CUDA_PKG_VERSION \
        cuda-cusparse-$CUDA_PKG_VERSION \
        cuda-npp-$CUDA_PKG_VERSION \
        cuda-cudart-$CUDA_PKG_VERSION && \
    ln -s cuda-8.0 /usr/local/cuda && \
    rm -rf /var/cache/yum/*

#### NVIDIA CUDA ####
RUN yum install -y cuda-8-0

#### NVIDIA CUDNN ####
ENV CUDNN_VERSION 6.0.21
LABEL com.nvidia.cudnn.version="${CUDNN_VERSION}"

# cuDNN license: https://developer.nvidia.com/cudnn/license_agreement
RUN CUDNN_DOWNLOAD_SUM=9b09110af48c9a4d7b6344eb4b3e344daa84987ed6177d5c44319732f3bb7f9c && \
    curl -fsSL http://developer.download.nvidia.com/compute/redist/cudnn/v6.0/cudnn-8.0-linux-x64-v6.0.tgz -O && \
    echo "$CUDNN_DOWNLOAD_SUM  cudnn-8.0-linux-x64-v6.0.tgz" | sha256sum -c - && \
    tar --no-same-owner -xzf cudnn-8.0-linux-x64-v6.0.tgz -C /usr/local --wildcards 'cuda/lib64/libcudnn.so.*' && \
    rm cudnn-8.0-linux-x64-v6.0.tgz && \
    ldconfig

#### TensorFlow ####
RUN yum install -y gcc gcc-c++ python34-pip python34-devel atlas atlas-devel gcc-gfortran openssl-devel libffi-devel

#### Use pip3 (Python3) ####
RUN pip3 install --upgrade pip \
  && pip3 install --upgrade virtualenv \
  && virtualenv --system-site-packages ~/venvs/tensorflow \
  && source ~/venvs/tensorflow/bin/activate \
  && pip3 install --upgrade numpy scipy wheel cryptography \
  && pip3 install Keras \
  && pip3 install jupyter \
  && pip3 install matplotlib \
  && pip3 install tensorflow-gpu

#### Notebook Config ####
COPY conf/jupyter/jupyter_notebook_config.py /root/.jupyter/

#### Copy sample notebooks ####
COPY conf/jupyter/notebooks /opt/notebooks

#### Jupyter has issues with being run directly ####
#   https://github.com/ipython/ipython/issues/7062
# We just add a little wrapper script.
COPY conf/jupyter/run_jupyter.sh /
RUN chmod a+x /run_jupyter.sh

#### Port ####
# IPython: 8888
EXPOSE 8888

#### Source to Image ####
# Copy the S2I scripts to /tmp/s2i since we set the label that way
COPY s2i/bin/ /opt/s2i
RUN chmod -R a+x /opt/s2i

# Allow arbitrary
USER 0
