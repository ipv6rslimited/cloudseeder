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
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" sudo nginx ca-certificates curl gnupg certbot python3 build-essential python3-certbot-nginx build-essential ffmpeg libjpeg-dev libmagic-dev libpq-dev  postgresql postgresql-contrib postgresql-client python3-dev libldap2-dev libsasl2-dev make unzip zlib1g-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg-dev redis-server python3-venv git gettext-base && \
    useradd --system --shell /bin/bash --create-home --home-dir /srv/funkwhale funkwhale && \
    (cd /srv/funkwhale && mkdir -p config api data/static data/media data/music front && chown -R funkwhale:funkwhale data)
RUN (cd /srv/funkwhale && curl -L -o "api-1.4.0.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/1.4.0/download?job=build_api" && \
     unzip "api-1.4.0.zip" -d extracted && \
     mv extracted/api/* api/ && \
     rm -rf extracted api-1.4.0.zip && \
     curl -L -o "front-1.4.0.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/1.4.0/download?job=build_front" && \
     unzip "front-1.4.0.zip" -d extracted && \
     mv extracted/front . && \
     rm -rf extracted front-1.4.0.zip && \
     python3 -m venv venv && \
     venv/bin/pip install --upgrade pip wheel && \
     venv/bin/pip install --editable ./api) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY root.sh /.root.sh
COPY target.sh /.target.sh

RUN chmod +x /.root.sh && \
    chmod +x /.target.sh

VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT [ "/lib/systemd/systemd" ]
