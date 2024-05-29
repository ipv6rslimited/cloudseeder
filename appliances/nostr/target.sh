#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=1

nostr_nginx_temp=$(cat <<EOF
server {
  server_name $SERVERNAME;
  listen 80;
  listen [::]:80;
  root /var/www/html;
  index index.html index.htm index.nginx-debian.html;
  location / {
    try_files $uri $uri/ =404;
  }
}
EOF
)

nostr_nginx=$(cat <<EOF
server {
  if (\$host = $SERVERNAME) {
    return 301 https://\$host\$request_uri;
  }
  listen 80;
  listen [::]:80;
  server_name $SERVERNAME;
  return 301 https://\$host\$request_uri;
}
server {
  listen 443 ssl http2;
  listen [::]:443 ssl ipv6only=on;
  server_name $SERVERNAME;
  ssl_certificate /etc/letsencrypt/live/$SERVERNAME/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$SERVERNAME/privkey.pem;
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
  add_header Strict-Transport-Security "max-age=31536000" always;
  ssl_trusted_certificate /etc/letsencrypt/live/$SERVERNAME/chain.pem;
  ssl_stapling on;
  ssl_stapling_verify on;

  client_max_body_size 20M;  
  location / {
  proxy_http_version 1.1;
  proxy_pass http://127.0.0.1:8080/;
  proxy_set_header Host \$host;  
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;  
  proxy_set_header X-Forwarded-Protocol \$scheme;
  proxy_set_header X-Forwarded-Host \$http_host;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection upgrade;
  proxy_set_header Accept-Encoding gzip;
  proxy_buffering off;
  }
}
EOF
)

nostr_systemd=$(cat <<EOF
[Unit]
Description=Nostr Rust Relay nostr-rs-relay
After=remote-fs.target network.target

[Install]
WantedBy=multi-user.target
  
[Service]
Type=simple
ExecStart=/root/nostr-rs-relay/target/release/nostr-rs-relay
WorkingDirectory=/root/nostr-rs-relay
Environment='RUST_LOG=info'
Restart=always
EOF
)

config_toml=$(cat <<EOF
[info]
relay_url = "wss://$SERVERNAME/"
name = "nostr-rs-relay"
description = "A newly created nostr-rs-relay.\n\nCustomize this with your own info."

# Administrative contact pubkey (32-byte hex, not npub)
pubkey = "$PUBKEY"
contact = "$CONTACTEMAIL"

# Favicon location.  Relative to the current directory.  Assumes an
# ICO format.
#favicon = "favicon.ico"

# URL of Relay's icon.
#relay_icon = "https://example.test/img.png"

[diagnostics]
# Enable tokio tracing (for use with tokio-console)
#tracing = false

[database]
engine = "sqlite"

# Directory for SQLite files.  Defaults to the current directory.  Can
# also be specified (and overriden) with the "--db dirname" command
# line option.
#data_directory = "."

#min_conn = 0

# Maximum number of SQLite reader connections.  Recommend setting this
# to approx the number of cores.
max_conn = `nproc`

[logging]
#folder_path = "./log"
#file_prefix = "nostr-relay"

[grpc]
# gRPC interfaces for externalized decisions and other extensions to
# functionality.
#
# Events can be authorized through an external service, by providing
# the URL below.  In the event the server is not accessible, events
# will be permitted.  The protobuf3 schema used is available in
# 'proto/nauthz.proto'.
# event_admission_server = "http://[::1]:50051"

# If the event admission server denies writes
# in any case (excluding spam filtering).
# This is reflected in the relay information document.
# restricts_write = true

[network]
address = "127.0.0.1"
port = 8080
remote_ip_header = "x-forwarded-for"
remote_ip_header = "cf-connecting-ip"
ping_interval = 300

[options]
reject_future_seconds = 1800

[limits]
# Limit events created per second, averaged over one minute.  Must be
# an integer.  If not set (or set to 0), there is no limit.  Note:
# this is for the server as a whole, not per-connection.
#
# Limiting event creation is highly recommended if your relay is
# public!
#
#messages_per_sec = 5

# Limit client subscriptions created, averaged over one minute.  Must
# be an integer.  If not set (or set to 0), defaults to unlimited.
# Strongly recommended to set this to a low value such as 10 to ensure
# fair service.
#subscriptions_per_min = 0

# UNIMPLEMENTED...
# Limit how many concurrent database connections a client can have.
# This prevents a single client from starting too many expensive
# database queries.  Must be an integer.  If not set (or set to 0),
# defaults to unlimited (subject to subscription limits).
#db_conns_per_client = 0

# Limit blocking threads used for database connections.  Defaults to 16.
#max_blocking_threads = 16

# Limit the maximum size of an EVENT message.  Defaults to 128 KB.
# Set to 0 for unlimited.
#max_event_bytes = 131072

# Maximum WebSocket message in bytes.  Defaults to 128 KB.
#max_ws_message_bytes = 131072

# Maximum WebSocket frame size in bytes.  Defaults to 128 KB.
#max_ws_frame_bytes = 131072

# Broadcast buffer size, in number of events.  This prevents slow
# readers from consuming memory.
#broadcast_buffer = 16384

# Event persistence buffer size, in number of events.  This provides
# backpressure to senders if writes are slow.
#event_persist_buffer = 4096

# Event kind blacklist. Events with these kinds will be discarded.
#event_kind_blacklist = [
#    70202,
#]

# Event kind allowlist. Events other than these kinds will be discarded.
#event_kind_allowlist = [
#    0, 1, 2, 3, 7, 40, 41, 42, 43, 44, 30023,
#]

# Rejects imprecise requests (kind only and author only etc)
# This is a temperary measure to improve the adoption of outbox model
# Its recommended to have this enabled
limit_scrapers = false

[authorization]
# Pubkey addresses in this array are whitelisted for event publishing.
# Only valid events by these authors will be accepted, if the variable
# is set.
pubkey_whitelist = [
  "$PUBKEY",
]
# Enable NIP-42 authentication
#nip42_auth = false
# Send DMs (kind 4 and 44) and gift wraps (kind 1059) only to their authenticated recipients
#nip42_dms = false

[verified_users]
# NIP-05 verification of users.  Can be "enabled" to require NIP-05
# metadata for event authors, "passive" to perform validation but
# never block publishing, or "disabled" to do nothing.
#mode = "disabled"

# Domain names that will be prevented from publishing events.
#domain_blacklist = ["wellorder.net"]

# Domain names that are allowed to publish events.  If defined, only
# events NIP-05 verified authors at these domains are persisted.
#domain_whitelist = ["example.com"]

# Consider an pubkey "verified" if we have a successful validation
# from the NIP-05 domain within this amount of time.  Note, if the
# domain provides a successful response that omits the account,
# verification is immediately revoked.
#verify_expiration = "1 week"

# How long to wait between verification attempts for a specific author.
#verify_update_frequency = "24 hours"

# How many consecutive failed checks before we give up on verifying
# this author.
#max_consecutive_failures = 20

[pay_to_relay]
# Enable pay to relay
#enabled = false

# The cost to be admitted to relay
#admission_cost = 4200

# The cost in sats per post
#cost_per_event = 0

# Url of lnbits api
#node_url = "<node url>"

# LNBits api secret
#api_secret = "<ln bits api>"

# Nostr direct message on signup
#direct_message=false

# Terms of service
terms_message = """
This service (and supporting services) are provided "as is", without warranty of any kind, express or implied.

By using this service, you agree:
* Not to engage in spam or abuse the relay service
* Not to disseminate illegal content
* That requests to delete content cannot be guaranteed
* To use the service in compliance with all applicable laws
* To grant necessary rights to your content for unlimited time
* To be of legal age and have capacity to use this service
* That the service may be terminated at any time without notice
* That the content you publish may be removed at any time without notice
* To have your IP address collected to detect abuse or misuse
* To cooperate with the relay to combat abuse or misuse
* You may be exposed to content that you might find triggering or distasteful
* The relay operator is not liable for content produced by users of the relay
"""

# Whether or not new sign ups should be allowed
sign_ups = false

# optional if 'direct_message=false'
#secret_key = "<nostr nsec>"

EOF
)

source /root/.cargo/env
cd /root/nostr-rs-relay
cargo build -q -r
echo "$config_toml" > /root/nostr-rs-relay/config.toml

echo "$nostr_systemd" > /etc/systemd/system/nostr.service
systemctl daemon-reload
systemctl enable --now nostr


 
echo "$nostr_nginx_temp" > /etc/nginx/sites-available/nostr.conf
ln -s /etc/nginx/sites-available/nostr.conf /etc/nginx/sites-enabled/nostr.conf
   
curl --max-time 2 http://$SERVERNAME
certbot --nginx --agree-tos --email $EMAIL --redirect --expand --non-interactive --nginx-server-root /etc/nginx/ --domain $SERVERNAME
rm /etc/nginx/sites-enabled/nostr.conf
echo "$nostr_nginx" > /etc/nginx/sites-available/nostr.conf
ln -s /etc/nginx/sites-available/nostr.conf /etc/nginx/sites-enabled/nostr.conf

systemctl reload nginx



echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "nostr" > "${TARGET_MARKER}.name"

exec "$@"
