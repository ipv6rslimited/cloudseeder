FROM docker.io/library/ubuntu:24.04
LABEL maintainer="ipv6rs"

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends netcat-openbsd cron apt-transport-https wireguard-tools iproute2 ca-certificates openssl openssh-server unattended-upgrades curl systemd && \
    rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/curl systemd-tmpfiles-setup* \
    /lib/systemd/system/curl systemd-update-utmp*

RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime && \
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" tzdata curl wget gnupg lsb-release ca-certificates git software-properties-common make apt-transport-https redis-server optipng pngquant jhead jpegoptim gifsicle imagemagick ffmpeg libvips-tools libpq-dev libxml2-dev libxslt1-dev file g++ libprotobuf-dev protobuf-compiler pkg-config gcc autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev libidn11-dev libicu-dev libjemalloc-dev nginx certbot python3 build-essential python3-certbot-nginx && \
    adduser --disabled-password --gecos "" mastodon && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    wget -O /usr/share/keyrings/postgresql.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list && \
    yes | DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    apt-get install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" nodejs postgresql postgresql-contrib && \
    corepack enable && \
    yarn set version classic && \
    su - mastodon -c "git clone https://github.com/rbenv/rbenv.git ~/.rbenv" && \
    su - mastodon -c "echo 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\"' >> ~/.bashrc" && \
    su - mastodon -c "echo 'eval \"\$(rbenv init -)\"' >> ~/.bashrc" && \
    su - mastodon -c "git clone --depth 25 https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build" && \
    su - mastodon -c "echo 'export PATH=\"\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\"' >> ~/.bashrc" && \
    su - mastodon -c "exec bash" && \
    su - mastodon -c "PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" RUBY_CONFIGURE_OPTS=--with-jemalloc rbenv install 3.3.5 && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" rbenv global 3.3.5 && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/shims/:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" gem install bundler --no-document" && \
    su - mastodon -c "PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" && git clone https://github.com/mastodon/mastodon.git live && cd live && git checkout faed9bf9f14f077443374f5eb3075b9878e24214 && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/shims/:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" bundle config deployment 'true' && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/shims/:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" bundle config without 'development test' && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/shims/:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" bundle install -j\$(getconf _NPROCESSORS_ONLN) && git checkout -- Gemfile.lock  && corepack prepare && yarn install --immutable" && \
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


