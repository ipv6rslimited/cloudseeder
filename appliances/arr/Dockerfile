FROM docker.io/library/ubuntu:24.04
LABEL maintainer="ipv6rs"

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends netcat-openbsd cron apt-transport-https wireguard-tools iproute2 ca-certificates openssl openssh-server unattended-upgrades curl systemd make && \
    rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/curl systemd-tmpfiles-setup* \
    /lib/systemd/system/curl systemd-update-utmp*

RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime && \
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" software-properties-common sudo nginx ca-certificates curl gnupg certbot apache2-utils libssl-dev python3 build-essential python3-certbot-nginx curl sqlite3 mediainfo libchromaprint-tools wget && \
    add-apt-repository ppa:qbittorrent-team/qbittorrent-stable -y && \
    yes | DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    apt-get install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" qbittorrent qbittorrent-nox && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/x64/) && \
    wget --content-disposition "https://github.com/Radarr/Radarr/releases/download/v5.18.4.9674/Radarr.master.5.18.4.9674.linux-core-${arch}.tar.gz" && \
    wget --content-disposition "https://github.com/Sonarr/Sonarr/releases/download/v4.0.13.2932/Sonarr.main.4.0.13.2932.linux-${arch}.tar.gz" && \
    wget --content-disposition "https://github.com/Lidarr/Lidarr/releases/download/v2.9.6.4552/Lidarr.master.2.9.6.4552.linux-core-${arch}.tar.gz" && \
    wget --content-disposition "https://github.com/Readarr/Readarr/releases/download/v0.4.10.2734/Readarr.develop.0.4.10.2734.linux-core-${arch}.tar.gz" && \
    wget --content-disposition "https://whisparr.servarr.com/v1/update/nightly/updatefile?os=linux&runtime=netcore&arch=${arch}" && \
    wget --content-disposition "https://github.com/Prowlarr/Prowlarr/releases/download/v1.30.2.4939/Prowlarr.master.1.30.2.4939.linux-core-${arch}.tar.gz" && \
    tar -xvzf Radarr*.linux*.tar.gz && \
    tar -xvzf Sonarr*.linux*.tar.gz && \
    tar -xvzf Lidarr*.linux*.tar.gz && \
    tar -xvzf Readarr*.linux*.tar.gz && \
    tar -xvzf Whisparr*.linux*.tar.gz && \
    tar -xvzf Prowlarr*.linux*.tar.gz && \
    mv Radarr /opt/ && \
    mv Sonarr /opt/ && \
    mv Lidarr /opt/ && \
    mv Readarr /opt/ && \
    mv Whisparr /opt/ && \
    mv Prowlarr/ /opt/ && \
    groupadd media && \
    adduser --disabled-password --gecos "" qbittorrent

RUN rm Radarr*.linux*.tar.gz && \
    rm Sonarr.*.tar.gz && \
    rm Lidarr*.linux*.tar.gz && \
    rm Readarr*.linux*.tar.gz && \
    rm Whisparr*.linux*.tar.gz && \
    rm Prowlarr*.linux*.tar.gz && \
    (cd /var/lib && \
     mkdir -p prowlarr radarr sonarr lidarr readarr whisparr && \
     chmod 0775 prowlarr radarr sonarr lidarr readarr whisparr && \
     chown root:media prowlarr radarr sonarr lidarr readarr whisparr) && \
    usermod -aG media qbittorrent && \
    mkdir -p /downloads && \
    chmod 0775 /downloads && \
    chown qbittorrent:media /downloads && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN wget --content-disposition https://github.com/NetworkConfiguration/openresolv/releases/download/v3.13.2/openresolv-3.13.2.tar.xz && \
    tar -xvf openresolv-*.tar.xz && \
    cd openresolv-* && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf openresolv-*.tar.xz && \
    rm -rf openresolv-*

COPY root.sh /.root.sh
COPY target.sh /.target.sh

RUN chmod +x /.root.sh && \
    chmod +x /.target.sh

VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT [ "/lib/systemd/systemd" ]
