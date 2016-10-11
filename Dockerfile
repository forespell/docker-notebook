FROM jupyter/datascience-notebook

USER root

# AWS EFS
RUN apt-get install -yq nfs-common

# XGBoost
RUN conda install -y gcc && \
    cd /usr/local/src && mkdir xgboost && cd xgboost && \
    git clone --recursive https://github.com/dmlc/xgboost.git && \
    cd xgboost && \
    make && cd python-package && python setup.py install && cd -

# TensorFlow
RUN pip3 install --upgrade https://storage.googleapis.com/tensorflow/linux/gpu/tensorflow-0.11.0rc0-cp35-cp35m-linux_x86_64.whl

USER $NB_USER
