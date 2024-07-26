FROM debian:bullseye-slim

ENV LANG C.UTF-8

# common haskell dependencies:
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        build-essential \
        ca-certificates \
        chrony \
        curl \
        dpkg-dev \
        git \
        gcc \
        gnupg \
        g++ \
        jq \
        libc6-dev \
        libncursesw5 \
        libffi-dev \
        libgmp-dev \
        liblzma-dev \
        libnuma-dev \
        libpq-dev \
        libssl-dev \
        libsystemd-dev \
        libtinfo-dev \
        libtool \
        make \
        netbase \
        pkg-config \
        procps \
        tmux \
        wget \
        xz-utils \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Install gpg keys (https://www.haskell.org/ghcup/install/):
RUN gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7D1E8AFD1D4A16D71FADA2F2CCC85C0E40C06A8C || \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys 7D1E8AFD1D4A16D71FADA2F2CCC85C0E40C06A8C || \
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys 7D1E8AFD1D4A16D71FADA2F2CCC85C0E40C06A8C
RUN gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys FE5AB6C91FEA597C3B31180B73EDE9E8CFBAEF01 || \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys FE5AB6C91FEA597C3B31180B73EDE9E8CFBAEF01 || \
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys FE5AB6C91FEA597C3B31180B73EDE9E8CFBAEF01
RUN gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 88B57FCF7DB53B4DB3BFA4B1588764FBE22D19C4 || \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys 88B57FCF7DB53B4DB3BFA4B1588764FBE22D19C4 || \
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys 88B57FCF7DB53B4DB3BFA4B1588764FBE22D19C4
RUN gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EAF2A9A722C0C96F2B431CA511AAD8CEDEE0CAEF || \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys EAF2A9A722C0C96F2B431CA511AAD8CEDEE0CAEF || \
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys EAF2A9A722C0C96F2B431CA511AAD8CEDEE0CAEF

# ghcup:
ARG GHC=9.2.8
ARG CABAL=3.10.1.0
ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1
ENV BOOTSTRAP_HASKELL_GHC_VERSION=${GHC}
ENV BOOTSTRAP_HASKELL_CABAL_VERSION=${CABAL}
RUN bash -c "curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh"
ENV PATH=${PATH}:/root/.local/bin
ENV PATH=${PATH}:/root/.ghcup/bin

# Libsodium
RUN git clone https://github.com/input-output-hk/libsodium && \
    cd libsodium && \
    git checkout dbb48cc && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

# Libsecp256k1; as used by cardano-base@0f3a867493059e650cda69e20a5cbf1ace289a57
RUN git clone https://github.com/bitcoin-core/secp256k1 && \
    cd secp256k1 && \
    git checkout ac83be33d0956faf6b7f61a60ab524ef7d6a473a && \
    ./autogen.sh && \
    ./configure --prefix=/usr --enable-module-schnorrsig --enable-experimental && \
    make && \
    make install

ARG BLST_VERSION=v0.3.11
ENV BLST_VERSION=${BLST_VERSION}
RUN git clone --depth 1 --branch ${BLST_VERSION} https://github.com/supranational/blst && \
    cd blst && \
    ./build.sh && \
    printf 'prefix=/usr/local\nexec_prefix=${prefix}\nlibdir=${exec_prefix}/lib\nincludedir=${prefix}/include\nName: libblst\nDescription: Multilingual BLS12-381 signature library\nURL: https://github.com/supranational/blst\nVersion: '${BLST_VERSION#v}'\nCflags: -I${includedir}\nLibs: -L${libdir} -lblst\n' > libblst.pc && \
    cp libblst.pc /usr/local/lib/pkgconfig/ && \
    cp bindings/blst_aux.h bindings/blst.h bindings/blst.hpp /usr/local/include/ && \
    cp libblst.a /usr/local/lib && \
    chmod 644 /usr/local/lib/libblst.a && \
    chmod 644 /usr/local/lib/pkgconfig/libblst.pc && \
    chmod 644 /usr/local/include/blst.h && \
    chmod 644 /usr/local/include/blst.hpp && \
    chmod 644 /usr/local/include/blst_aux.h

ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
ENV PATH="/root/.cabal/bin:${PATH}"

CMD ["ghci"]
