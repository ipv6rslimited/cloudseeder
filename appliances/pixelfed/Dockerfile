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
    apt-get install -y --no-install-recommends software-properties-common gnupg && \
    add-apt-repository ppa:ondrej/php && \
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" sudo expect nginx mysql-server ca-certificates curl certbot python3 build-essential python3-certbot-nginx php8.2 php8.2-redis php8.2-gd php8.2-bcmath php8.2-ctype php8.2-curl php8.2-exif php8.2-iconv php8.2-intl php8.2-imagick php8.2-mbstring php8.2-tokenizer php8.2-xml php8.2-zip php8.2-mysql php8.2-fpm ffmpeg redis git libgl-dev gcc libc6-dev libjpeg-dev make optipng pngquant zip unzip && \
    sed -i "/^bind-address\s*=/c\bind-address            = 127.0.0.1,::1" /etc/mysql/mysql.conf.d/mysqld.cnf && \
    sed -i "/^mysqlx-bind-address\s*=/c\mysqlx-bind-address     = 127.0.0.1,::1" /etc/mysql/mysql.conf.d/mysqld.cnf && \
    adduser --disabled-password --gecos "" pixel && \
    usermod -aG sudo pixel && \
    echo "pixel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    su - pixel -c "php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\"" && \
    su - pixel -c "sudo php composer-setup.php" && \
    su - pixel -c "rm -rf composer-setup.php" && \
    su - pixel -c "sudo mv composer.phar /usr/local/bin/composer"

RUN git clone https://github.com/tjko/jpegoptim.git && \
    (cd jpegoptim && ./configure && make && make strip && make install && cd .. && rm -rf jpegoptim) && \
    (cd /var/www/ && rm -rf html && git clone -b v0.12.1 https://github.com/pixelfed/pixelfed.git html && cd html && \
     chown -R www-data:www-data . && \
     find . -type d -exec chmod 755 {} + && \
     find . -type f -exec chmod 644 {} +) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY root.sh /.root.sh
COPY target.sh /.target.sh

RUN chmod +x /.root.sh && \
    chmod +x /.target.sh

VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT [ "/lib/systemd/systemd" ]
