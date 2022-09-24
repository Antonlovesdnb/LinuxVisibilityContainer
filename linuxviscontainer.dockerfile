# docker build -t linuxvis -f linuxviscontainer.dockerfile .
# docker run -d --name linuxvis --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v $PWD/logs/:/var/log/ linuxvis
# docker exec -it linuxvis /bin/bash

# Using: https://hub.docker.com/r/jrei/systemd-ubuntu
FROM --platform=linux/amd64 jrei/systemd-ubuntu:latest

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update

# From: https://andreybleme.com/2022-05-22/running-ebpf-programs-on-docker-containers/

RUN apt-get -y install wget && apt-get -y install curl && apt-get -y install jq && apt-get install -y lsb-release && apt-get install -y systemd && apt-get install -y init && apt-get install -y rsyslog 

RUN apt-get update && \
    apt-get install -y build-essential git cmake \
                       zlib1g-dev libevent-dev \
                       libelf-dev llvm \
                       clang libc6-dev-i386

RUN mkdir /src && \
    git init
WORKDIR /src

# Link asm/byteorder.h into eBPF
RUN ln -s /usr/include/x86_64-linux-gnu/asm/ /usr/include/asm

# Build libbpf as a static lib
RUN git clone https://github.com/libbpf/libbpf-bootstrap.git && \
    cd libbpf-bootstrap && \
    git submodule update --init --recursive

RUN cd libbpf-bootstrap/libbpf/src && \
    make BUILD_STATIC_ONLY=y && \
    make install BUILD_STATIC_ONLY=y LIBDIR=/usr/lib/x86_64-linux-gnu/

# Clones the linux kernel repo and use the latest linux kernel source BPF headers 
RUN git clone --depth 1 git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git && \
    cp linux/include/uapi/linux/bpf* /usr/include/linux/

# End of ebpf setup section

RUN wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb

RUN dpkg -i packages-microsoft-prod.deb

RUN apt-get -y update

RUN apt-get -y install sysinternalsebpf && apt-get -y install sysmonforlinux

#Config file from: https://techcommunity.microsoft.com/t5/microsoft-sentinel-blog/automating-the-deployment-of-sysmon-for-linux-and-azure-sentinel/ba-p/2847054
RUN wget https://gist.githubusercontent.com/Cyb3rWard0g/bcf1514cc340197f0076bf1da8954077/raw/293db31bb81c48ff18a591574a6f2bf946282602/SysmonForLinux-CollectAll-Config.xml

#Sysmon does not want to start unless this file is there, not sure why it isn't installed with the package
RUN touch /opt/sysinternalsEBPF/sysinternalsEBPF_offsets.conf

COPY start.sh /src/start.sh

ENTRYPOINT ["/usr/sbin/init"]

CMD ["systemctl"]

VOLUME ["/var/log/"]