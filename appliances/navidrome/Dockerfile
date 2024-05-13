FROM ubuntu:22.04
LABEL maintainer="ipv6rs"

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends netcat cron apt-transport-https wireguard-tools iproute2 ca-certificates openssl openssh-server openresolv unattended-upgrades curl systemd && \
    rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/curl systemd-tmpfiles-setup* \
    /lib/systemd/system/curl systemd-update-utmp*

RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime && \
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" wget sudo tzdata nginx ffmpeg ca-certificates curl certbot python3 python3-certbot-nginx && \
    adduser --disabled-password --gecos "" navidrome && \
    mkdir -p /home/navidrome/music && \
    chown navidrome:navidrome /home/navidrome/music && \
    sudo install -d -o navidrome -g navidrome /opt/navidrome && \
    sudo install -d -o navidrome -g navidrome /var/lib/navidrome && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    wget https://github.com/navidrome/navidrome/releases/download/v0.52.5/navidrome_0.52.5_linux_${arch}.tar.gz -O Navidrome.tar.gz && \
    sudo tar -xvzf Navidrome.tar.gz -C /opt/navidrome/ && \
    sudo chown -R navidrome:navidrome /opt/navidrome && \ 
    rm Navidrome.tar.gz && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY root.sh /.root.sh
COPY target.sh /.target.sh

RUN chmod +x /.root.sh && \
    chmod +x /.target.sh

VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT [ "/lib/systemd/systemd" ]
