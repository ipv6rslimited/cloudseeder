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
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" python3 python3-dev python-is-python3 curl sudo unzip vim ca-certificates gnupg nginx certbot ffmpeg postgresql postgresql-contrib openssl g++ make redis-server git cron wget gnupg build-essential && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list && \
    yes | DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    apt-get install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" nodejs && \
    npm install --global yarn && \
    adduser --disabled-password --gecos "" --home /var/www/peertube --shell /bin/bash peertube && \
    chmod 755 /var/www/peertube && \
    sudo -u peertube mkdir /var/www/peertube/config /var/www/peertube/storage /var/www/peertube/versions && \
    sudo -u peertube chmod 750 /var/www/peertube/config && \
    VERSION="v6.0.4" && \
    (cd /var/www/peertube/versions && \
     sudo -u peertube wget -q "https://github.com/Chocobozzz/PeerTube/releases/download/${VERSION}/peertube-${VERSION}.zip" && \
     sudo -u peertube unzip -q peertube-${VERSION}.zip && \
     sudo -u peertube rm peertube-${VERSION}.zip && \
     cd .. && \
     sudo -u peertube ln -s versions/peertube-${VERSION} ./peertube-latest && \
     cd ./peertube-latest && \
     sudo -H -u peertube yarn install --production --pure-lockfile) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY root.sh /.root.sh
COPY target.sh /.target.sh

RUN chmod +x /.root.sh && \
    chmod +x /.target.sh

VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT [ "/lib/systemd/systemd" ]
