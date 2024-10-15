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
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" ca-certificates gnupg sudo curl apache2 mysql-server libapache2-mod-php php-bz2 php-gd php-mysql php-curl php-mbstring php-imagick php-zip php-ctype php-curl php-dom php-json php-posix php-bcmath php-xml php-intl php-gmp zip unzip wget php8.1-fpm php8.1-apcu redis-server php-redis certbot python3-certbot-apache python3 wget && \
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0C54D189F4BA284D && \
    echo 'deb https://www.collaboraoffice.com/repos/CollaboraOnline/CODE-ubuntu2204 ./' | sudo tee /etc/apt/sources.list.d/collabora.list && \
    apt-get update -y && \
    apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" coolwsd code-brand && \
    sed -i "/^bind-address\s*=/c\bind-address            = 127.0.0.1,::1" /etc/mysql/mysql.conf.d/mysqld.cnf && \
    sed -i "/^mysqlx-bind-address\s*=/c\mysqlx-bind-address     = 127.0.0.1,::1" /etc/mysql/mysql.conf.d/mysqld.cnf && \
    a2enmod rewrite dir mime env headers && \
    (cd /var/www/ && wget https://download.nextcloud.com/server/releases/latest.zip && unzip latest.zip && rm -rf latest.zip) && \
    chown -R www-data:www-data /var/www/nextcloud/ && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY root.sh /.root.sh
COPY target.sh /.target.sh

RUN chmod +x /.root.sh && \
    chmod +x /.target.sh

VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT [ "/lib/systemd/systemd" ]

