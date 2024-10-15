FROM docker.io/library/ubuntu:22.04
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
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" wget sudo nginx ca-certificates curl gnupg certbot expect python3 build-essential python3-certbot-nginx
RUN (mkdir /root/vw-image && \
     cd /root/vw-image && \
     wget https://raw.githubusercontent.com/jjlin/docker-image-extract/main/docker-image-extract && \
     arch=$(arch | sed "s/aarch64/linux\/arm64/" | sed "s/x86_64/linux\/amd64/") && \
     chmod +x docker-image-extract && \
     bash -c "./docker-image-extract -p $arch vaultwarden/server:1.25.0-alpine")

RUN adduser --disabled-password --gecos "" --system --disabled-login --group lemmy && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN mkdir /opt/vaultwarden && \
    mkdir /var/lib/vaultwarden && \
    mkdir /var/lib/vaultwarden/data && \
    adduser --disabled-password --gecos "" vaultwarden && \
    mv /root/vw-image/output/vaultwarden /opt/vaultwarden && \
    mv /root/vw-image/output/web-vault /var/lib/vaultwarden && \
    chown -R vaultwarden:vaultwarden /var/lib/vaultwarden && \
    chown -R vaultwarden:vaultwarden /opt/vaultwarden && \
    rm -Rf /root/vw-image && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY root.sh /.root.sh
COPY target.sh /.target.sh

RUN chmod +x /.root.sh && \
    chmod +x /.target.sh

VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT [ "/lib/systemd/systemd" ]
