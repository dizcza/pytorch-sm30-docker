# NOTE: To build this you will need a docker version > 18.06 with
#       experimental enabled and DOCKER_BUILDKIT=1
#
#       If you do not use buildkit you are not going to have a good time
#
#       For reference:
#           https://docs.docker.com/develop/develop-images/build_enhancements/
FROM nvidia/cuda:10.2-cudnn7-devel-ubuntu18.04
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        libjpeg-dev \
        libpng-dev && \
    rm -rf /var/lib/apt/lists/*
ENV PATH /opt/conda/bin:$PATH

ENV CUDA_CHANNEL nvidia
ENV CUDA_VERSION 10.2
ENV INSTALL_CHANNEL pytorch
ENV PYTHON_VERSION 3.9
ENV PYTORCH_VERSION v1.10.2

RUN curl -fsSL -o ~/miniconda.sh -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh  && \
    chmod +x ~/miniconda.sh && \
    ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda install -y python=${PYTHON_VERSION} conda-build pyyaml numpy ipython requests typing_extensions pip && \
    /opt/conda/bin/pip install setuptools==59.5.0 && \
    /opt/conda/bin/conda clean -ya

WORKDIR /opt/pytorch
RUN curl -fsSL -o nccl.tar.gz https://github.com/NVIDIA/nccl/archive/refs/tags/v2.9.9-1.tar.gz && tar xzf nccl.tar.gz && rm nccl.tar.gz
RUN cd nccl-2.9.9-1 && make -j3 src.build NVCC_GENCODE="-gencode=arch=compute_30,code=sm_30" && make install

RUN curl -fsSL -o pytorch.tar.gz https://github.com/pytorch/pytorch/releases/download/${PYTORCH_VERSION}/pytorch-${PYTORCH_VERSION}.tar.gz && tar xzf pytorch.tar.gz && rm pytorch.tar.gz

RUN cd pytorch-${PYTORCH_VERSION} && \
    echo ${PYTORCH_VERSION} | tail -c +2 > version.txt && \
    TORCH_CUDA_ARCH_LIST="3.0" TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CMAKE_PREFIX_PATH="$(dirname $(which conda))/../" \
    USE_ROCM=0 USE_SYSTEM_NCCL=1 \
    # BUILD_CAFFE2=0 BUILD_TEST=0 \
    python setup.py install

ENV CONDA_OVERRIDE_CUDA=${CUDA_VERSION}
RUN /opt/conda/bin/conda install -c "${INSTALL_CHANNEL}" -c "${CUDA_CHANNEL}" -y python=${PYTHON_VERSION} cudatoolkit=${CUDA_VERSION} && /opt/conda/bin/conda clean -ya

ENV TORCHVISION_VERSION v0.11.3
RUN sed -i "s/supported_arches = \[/supported_arches = \['3.0', /g" /opt/conda/lib/python3.9/site-packages/torch/utils/cpp_extension.py
RUN export TORCHVISION_VERSION_SHORT=$(echo ${TORCHVISION_VERSION} | tail -c +2) ; \
    curl -fsSL -o torchvision.tar.gz https://github.com/pytorch/vision/archive/refs/tags/${TORCHVISION_VERSION}.tar.gz && \
    tar xzf torchvision.tar.gz && \
    rm torchvision.tar.gz && \
    cd vision-${TORCHVISION_VERSION_SHORT} && \
    echo ${TORCHVISION_VERSION_SHORT} > version.txt && \
    FORCE_CUDA=1 TORCH_CUDA_ARCH_LIST="3.0" pip install .

LABEL com.nvidia.volumes.needed="nvidia_driver"
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        libjpeg-dev \
        libpng-dev && \
    rm -rf /var/lib/apt/lists/*
ENV PATH /opt/conda/bin:$PATH
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64:/opt/pytorch/pytorch-"$PYTORCH_VERSION"/torch/lib

