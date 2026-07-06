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
        openssh-client \
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

ENV VERILATOR_HOME=/opt/verilator
ENV PATH="${VERILATOR_HOME}/bin:${PATH}"

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
    ./configure --prefix=${VERILATOR_HOME} && \
    make -j${VERILATOR_JOBS} && \
    make install && \
    ${VERILATOR_HOME}/bin/verilator --version && \
    rm -rf /tmp/verilator

WORKDIR /workspace
USER aoc

CMD ["/bin/bash"]


FROM common_pkg_provider AS systemc_provider

USER root

ARG SYSTEMC_VERSION=2.3.4
ARG SYSTEMC_JOBS=2

ENV SYSTEMC_HOME=/opt/systemc
ENV SYSTEMC_CXXFLAGS="-I/opt/systemc/include"
ENV SYSTEMC_LDFLAGS="-L/opt/systemc/lib -lsystemc -Wl,-rpath,/opt/systemc/lib -pthread"
ENV LD_LIBRARY_PATH="/opt/systemc/lib"

RUN apt-get update && \
    apt-get install -y --no-install-recommends cmake && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN git clone https://github.com/accellera-official/systemc.git /tmp/systemc && \
    cd /tmp/systemc && \
    git checkout ${SYSTEMC_VERSION} && \
    cmake -S . -B build \
        -DCMAKE_INSTALL_PREFIX=${SYSTEMC_HOME} \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DBUILD_SHARED_LIBS=ON && \
    cmake --build build --parallel ${SYSTEMC_JOBS} && \
    cmake --install build && \
    printf '%s\n' \
        '#include <systemc>' \
        '#include <iostream>' \
        '' \
        'int sc_main(int argc, char* argv[]) {' \
        '    std::cout << sc_core::sc_version() << std::endl;' \
        '    return 0;' \
        '}' \
        > /tmp/systemc_test.cpp && \
    g++ ${SYSTEMC_CXXFLAGS} /tmp/systemc_test.cpp ${SYSTEMC_LDFLAGS} -o /tmp/systemc_test && \
    /tmp/systemc_test && \
    rm -rf /tmp/systemc /tmp/systemc_test.cpp /tmp/systemc_test

WORKDIR /workspace
USER aoc

CMD ["/bin/bash"]


FROM common_pkg_provider AS release

ARG USERNAME=aoc

ENV VERILATOR_HOME=/opt/verilator
ENV SYSTEMC_HOME=/opt/systemc
ENV PATH="/opt/verilator/bin:/home/${USERNAME}/.local/bin:${PATH}"
ENV SYSTEMC_CXXFLAGS="-I/opt/systemc/include"
ENV SYSTEMC_LDFLAGS="-L/opt/systemc/lib -lsystemc -Wl,-rpath,/opt/systemc/lib -pthread"
ENV LD_LIBRARY_PATH="/opt/systemc/lib"

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        perl \
        libfl2 \
        zlib1g \
        liblz4-1 && \
    mkdir -p /home/${USERNAME}/.local/bin \
             /home/${USERNAME}/.local/verilator && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.local && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=verilator_provider /opt/verilator /opt/verilator
COPY --from=systemc_provider /opt/systemc /opt/systemc

COPY eman /usr/local/bin/eman

RUN chmod 755 /usr/local/bin/eman && \
    verilator --version && \
    printf '%s\n' \
        '#include <systemc>' \
        '#include <iostream>' \
        '' \
        'int sc_main(int argc, char* argv[]) {' \
        '    std::cout << sc_core::sc_version() << std::endl;' \
        '    return 0;' \
        '}' \
        > /tmp/systemc_release_test.cpp && \
    g++ ${SYSTEMC_CXXFLAGS} /tmp/systemc_release_test.cpp ${SYSTEMC_LDFLAGS} -o /tmp/systemc_release_test && \
    /tmp/systemc_release_test && \
    rm -f /tmp/systemc_release_test.cpp /tmp/systemc_release_test

WORKDIR /workspace

USER ${USERNAME}

CMD ["/bin/bash"]