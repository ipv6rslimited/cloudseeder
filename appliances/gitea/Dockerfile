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
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" sudo nginx mysql-server ca-certificates git wget curl gnupg certbot python3 build-essential python3-certbot-nginx && \
    sed -i "/^bind-address\s*=/c\bind-address            = 127.0.0.1,::1" /etc/mysql/mysql.conf.d/mysqld.cnf && \
    sed -i "/^mysqlx-bind-address\s*=/c\mysqlx-bind-address     = 127.0.0.1,::1" /etc/mysql/mysql.conf.d/mysqld.cnf && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    wget https://github.com/go-gitea/gitea/releases/download/v1.21.11/gitea-1.21.11-linux-${arch} -O /usr/bin/gitea && \
    chmod 755 /usr/bin/gitea && \
    adduser --system --shell /bin/bash --group --gecos "" --disabled-password --home /home/git git && \
    mkdir -p /etc/gitea /var/lib/gitea/custom /var/lib/gitea/data /var/lib/gitea/indexers /var/lib/gitea/public /var/lib/gitea/log && \
    chown -R git:git /etc/gitea /var/lib/gitea/custom /var/lib/gitea/data /var/lib/gitea/indexers /var/lib/gitea/public /var/lib/gitea/log && \
    chmod 750 /var/lib/gitea/data /var/lib/gitea/indexers /var/lib/gitea/log && \
    chmod 770 /etc/gitea && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY root.sh /.root.sh
COPY target.sh /.target.sh

RUN chmod +x /.root.sh && \
    chmod +x /.target.sh

VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT [ "/lib/systemd/systemd" ]
