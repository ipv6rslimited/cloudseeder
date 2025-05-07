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
    apt update && \
    echo "11" | apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" git sudo nginx ca-certificates wget curl gnupg certbot python3 build-essential python3-certbot-nginx protobuf-compiler gcc ffmpeg exiftool libgexiv2-dev && \
    sudo mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list && \
    yes | DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    apt-get install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" postgresql-contrib libssl-dev libpq-dev postgresql nodejs && \
    echo "local   lemmy           lemmy                                   md5" >> /etc/postgresql/16/main/pg_hba.conf && \
    wget 'https://dist.1-2.dev/imei.sh' -qO /root/imei.sh && \
    bash /root/imei.sh && \
    rm /root/imei.sh

RUN adduser --disabled-password --gecos "" --system --disabled-login --home /opt/lemmy --group lemmy && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    bash -c ". "$HOME/.cargo/env" && cd /root && git clone https://github.com/LemmyNet/lemmy.git lemmy && cd lemmy && git checkout 0.19.11 &&  git clone https://github.com/LemmyNet/lemmy-translations.git crates/utils/translations && cd crates/utils/translations && git checkout 70a2384b595c17dfe2096419cd1b381f638ced9a && cd /root/lemmy && echo \"pub const VERSION: &str = \\\"$(git describe --tag)\\\";\" > "crates/utils/src/version.rs" && cargo build --release --features embed-pictrs"

RUN mkdir -p /opt/lemmy && \
    mkdir /opt/lemmy/lemmy-server && \
    mkdir /opt/lemmy/pictrs && \
    mkdir /opt/lemmy/pictrs/files && \
    mkdir /opt/lemmy/pictrs/sled-repo && \
    mkdir /opt/lemmy/pictrs/old && \
    cp /root/lemmy/target/release/lemmy_server /opt/lemmy/lemmy-server/lemmy_server && \
    chown -R lemmy:lemmy /opt/lemmy/ && \
    npm i -g pnpm && \
    cd /opt/lemmy && \
    sudo -u lemmy bash -c "git clone https://github.com/LemmyNet/lemmy-ui.git --recursive && cd lemmy-ui && git checkout 0.19.11 && echo \"export const VERSION = '$(git describe --tag)';\" > "src/shared/version.ts" && pnpm i && pnpm build:prod" && \
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