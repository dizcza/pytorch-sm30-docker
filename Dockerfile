# NOTE: To build this you will need a docker version > 18.06 with
#       experimental enabled and DOCKER_BUILDKIT=1
#
#       If you do not use buildkit you are not going to have a good time
#
#       For reference:
#           https://docs.docker.com/develop/develop-images/build_enhancements/
ARG BASE_IMAGE=ubuntu:18.04
ARG PYTHON_VERSION=3.9

FROM ${BASE_IMAGE} as dev-base
RUN --mount=type=cache,id=apt-dev,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        ccache \
        cmake \
        curl \
        libjpeg-dev \
        libpng-dev && \
    rm -rf /var/lib/apt/lists/*
RUN /usr/sbin/update-ccache-symlinks
RUN mkdir /opt/ccache && ccache --set-config=cache_dir=/opt/ccache
ENV PATH /opt/conda/bin:$PATH

FROM dev-base as conda
ARG PYTHON_VERSION=3.9
RUN curl -fsSL -o ~/miniconda.sh -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh  && \
    chmod +x ~/miniconda.sh && \
    ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda install -y python=${PYTHON_VERSION} conda-build pyyaml numpy ipython requests typing_extensions && \
    /opt/conda/bin/conda clean -ya

FROM dev-base as submodule-update
ARG PYTORCH_VERSION=v1.10.2
WORKDIR /opt/pytorch
RUN curl -fsSL -o nccl.tar.gz https://github.com/NVIDIA/nccl/archive/refs/tags/v2.9.9-1.tar.gz && tar xzf nccl.tar.gz && rm nccl.tar.gz
RUN cd nccl-2.9.9-1 && make -j3 src.build NVCC_GENCODE="-gencode=arch=compute_30,code=sm_30" && make install

RUN curl -fsSL -o pytorch.tar.gz https://github.com/pytorch/pytorch/releases/download/${PYTORCH_VERSION}/pytorch-${PYTORCH_VERSION}.tar.gz && tar xzf pytorch.tar.gz && rm pytorch.tar.gz

FROM conda as build
ARG PYTORCH_VERSION=v1.10.2
WORKDIR /opt/pytorch
COPY --from=conda /opt/conda /opt/conda
COPY --from=submodule-update /opt/pytorch /opt/pytorch

RUN --mount=type=cache,target=/opt/ccache \
    cd pytorch-${PYTORCH_VERSION} && \
    TORCH_CUDA_ARCH_LIST="3.0" TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CMAKE_PREFIX_PATH="$(dirname $(which conda))/../" \
    USE_ROCM=0 USE_SYSTEM_NCCL=1 \
    # BUILD_CAFFE2=0 BUILD_TEST=0 \
    python setup.py install

FROM conda as conda-installs
ARG PYTHON_VERSION=3.9
ARG CUDA_VERSION=10.2
ARG CUDA_CHANNEL=nvidia
ARG INSTALL_CHANNEL=pytorch-nightly
ENV CONDA_OVERRIDE_CUDA=${CUDA_VERSION}
RUN /opt/conda/bin/conda install -c "${INSTALL_CHANNEL}" -c "${CUDA_CHANNEL}" -y python=${PYTHON_VERSION} cudatoolkit=${CUDA_VERSION} pytorch-mutex && \
    /opt/conda/bin/conda install -c "${INSTALL_CHANNEL}" --no-deps torchvision && \
    /opt/conda/bin/conda clean -ya

FROM ${BASE_IMAGE} as official
ARG PYTORCH_VERSION=v1.10.2
LABEL com.nvidia.volumes.needed="nvidia_driver"
RUN --mount=type=cache,id=apt-final,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        libjpeg-dev \
        libpng-dev && \
    rm -rf /var/lib/apt/lists/*
COPY --from=conda-installs /opt/conda /opt/conda
ENV PATH /opt/conda/bin:$PATH
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV PYTORCH_VERSION ${PYTORCH_VERSION}
WORKDIR /workspace

FROM official as dev
# Should override the already installed version from the official-image stage
COPY --from=build /opt/conda /opt/conda
