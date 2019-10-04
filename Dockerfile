FROM ubuntu:18.04
ARG DEBIAN_FRONTEND=noninteractive
LABEL maintainer="Jonathan Hanson (jonathan@jonathan-hanson.org)"

# The git repository from which to checkout micropython
ARG MICROPYTHON_REPO=https://github.com/micropython/micropython.git

# The git tag of the micropython repository with which to do the initial build
ARG MICROPYTHON_VERSION=v1.11

# Set up the volume mounts for getting files into and out of the container
VOLUME [ "/opt/micropython/input" ]
VOLUME [ "/opt/micropython/artifacts" ]

# Create the user with which we'll run the build
RUN useradd -m mpbuild
WORKDIR /home/mpbuild/

# Install git
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
USER mpbuild

# Pull down the esp-open-sdk project repository
RUN git clone --recursive https://github.com/pfalcon/esp-open-sdk.git && \
    git -C esp-open-sdk submodule sync && \
    git -C esp-open-sdk submodule update --recursive --init

# Install packages relevant to the esp-open-sdk project
# see https://github.com/pfalcon/esp-open-sdk#debianubuntu
USER root
RUN apt-get update && apt-get install -y \
        autoconf \
        automake \
        bash \
        bison \
        bzip2 \
        flex \
        g++ \
        gawk \
        gcc \
        gperf \
        help2man \
        libexpat-dev \
        libtool \
        libtool-bin \
        make \
        ncurses-dev \
        python \
        python-dev \
        python-serial \
        sed \
        texinfo \
        unrar-free \
        unzip \
        wget \
    && rm -rf /var/lib/apt/lists/*
USER mpbuild

# Build esp-open-sdk
RUN cd esp-open-sdk && make STANDALONE=y
ENV PATH="/home/mpbuild/esp-open-sdk/xtensa-lx106-elf/bin:$PATH"


# Pull down the micropython repository at the particular branch in question
RUN git clone --recursive ${MICROPYTHON_REPO} && \
    git -C micropython checkout tags/${MICROPYTHON_VERSION} && \
    git -C micropython submodule sync && \
    git -C micropython submodule update --recursive --init

# Install packages relevant to micropython and its ports
USER root
RUN apt-get update && apt-get install -y \
        libffi-dev \
        pkg-config \
        python3 \
    && rm -rf /var/lib/apt/lists/*
USER mpbuild

# Build the micropython cross-compiler
RUN cd micropython/mpy-cross && make

# Build the various ports
RUN cd micropython/ports/unix && make
RUN cd micropython/ports/esp8266 && make
# - More port builds could be added here -
# - Be aware we'd likely have to build more -
# - tools like the ESP SDK above -


# Set up some user tools that it might be nice
# to have later
USER root
RUN apt-get update && apt-get install -y \
        python-pip \
        screen \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --upgrade \
        pip \
        setuptools \
        wheel
RUN pip install \
        adafruit-ampy \
        ecdsa \
        esptool \
        pyaes \
        "pyserial>=3.0"
