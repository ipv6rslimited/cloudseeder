FROM docker.io/library/ubuntu:24.04
LABEL maintainer="ipv6rs"

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends netcat-openbsd cron apt-transport-https wireguard-tools iproute2 ca-certificates openssl openssh-server  unattended-upgrades curl systemd && \
    rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/curl systemd-tmpfiles-setup* \
    /lib/systemd/system/curl systemd-update-utmp*

RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime && \
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" sudo nginx ca-certificates wget curl gnupg certbot python3 build-essential python3-certbot-nginx && \
    mkdir -p /etc/apt/keyrings && \
    wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc |  gpg --dearmor | sudo tee /etc/apt/keyrings/mongodb.gpg > /dev/null && \
    echo "deb [ arch=amd64,arm64 signed-by=/etc/apt/keyrings/mongodb.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [trusted=yes] https://deb.nodesource.com/node_22.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list && \
    yes | DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    apt-get install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" mongodb-org nodejs && \
    curl -L https://releases.rocket.chat/7.4.1/download -o /opt/rocket.chat.tgz && \
    tar -xzf /opt/rocket.chat.tgz -C /opt && \
    mv /opt/bundle/ /opt/RocketChat && \
    adduser --disabled-password --gecos "" rocketchat && \
    sudo chown -R rocketchat:rocketchat /opt/RocketChat && \
    sed -i "s/^#  engine:/  engine: wiredTiger/"  /etc/mongod.conf && \
    sed -i "s/^#replication:/replication:\n  replSetName: rs01/" /etc/mongod.conf && \
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
