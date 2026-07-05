FROM ubuntu:26.04 AS base

ARG USERNAME=aoc
ARG USER_UID=1001
ARG USER_GID=1001

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends tzdata && \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone && \
    groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} && \
    mkdir -p /workspace && \
    chown -R ${USERNAME}:${USERNAME} /workspace && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

USER ${USERNAME}

CMD ["/bin/bash"]


FROM base AS common_pkg_provider

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        vim \
        git \
        curl \
        wget \
        ca-certificates \
        build-essential \
        python3 \
        python3-pip && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER aoc

CMD ["/bin/bash"]


FROM common_pkg_provider AS verilator_provider

USER root

ARG VERILATOR_VERSION=stable
ARG VERILATOR_JOBS=2

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        autoconf \
        flex \
        bison \
        help2man \
        perl \
        libfl-dev \
        zlib1g-dev \
        liblz4-dev \
        ccache && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN git clone --depth 1 --branch ${VERILATOR_VERSION} https://github.com/verilator/verilator.git /tmp/verilator && \
    cd /tmp/verilator && \
    autoconf && \
    ./configure && \
    make -j${VERILATOR_JOBS} && \
    make install && \
    verilator --version && \
    rm -rf /tmp/verilator

WORKDIR /workspace

USER aoc

CMD ["/bin/bash"]
