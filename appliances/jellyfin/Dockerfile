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
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" sudo software-properties-common ca-certificates curl gnupg certbot python3 apache2 python3-certbot-apache && \
    add-apt-repository universe -y && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg && \
    echo "Types: deb" > /etc/apt/sources.list.d/jellyfin.sources && \
    echo "URIs: https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release )" >>/etc/apt/sources.list.d/jellyfin.sources && \
    echo "Suites: $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release )" >>  /etc/apt/sources.list.d/jellyfin.sources && \
    echo "Components: main" >>  /etc/apt/sources.list.d/jellyfin.sources && \
    echo "Architectures: $( dpkg --print-architecture )" >>  /etc/apt/sources.list.d/jellyfin.sources && \
    echo "Signed-By: /etc/apt/keyrings/jellyfin.gpg" >>  /etc/apt/sources.list.d/jellyfin.sources && \
    yes | DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    apt-get install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" jellyfin && \
    mkdir -p /media && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY root.sh /.root.sh
COPY target.sh /.target.sh

RUN chmod +x /.root.sh && \
    chmod +x /.target.sh

VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT [ "/lib/systemd/systemd" ]


