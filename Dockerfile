FROM jupyter/datascience-notebook

USER root

# Update conda packages
RUN conda update --all --yes && conda install tqdm -c conda-forge -y

# XGBoost
RUN conda install -y gcc && \
    cd /usr/local/src && mkdir xgboost && cd xgboost && \
    git clone --recursive https://github.com/dmlc/xgboost.git && \
    cd xgboost && \
    make && cd python-package && python setup.py install && cd -

# TensorFlow
RUN pip3 install https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-0.12.0rc1-cp35-cp35m-linux_x86_64.whl

USER $NB_USER
