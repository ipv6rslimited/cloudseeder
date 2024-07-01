#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

prosody_cfg_lua=$(cat <<EOF
admins = { "$ADMIN" }
plugin_paths = { "/usr/lib/prosody/modules/" }
modules_enabled = {
  "disco"; -- Service discovery
  "roster"; -- Allow users to have a roster. Recommended ;)
  "saslauth"; -- Authentication for clients and servers. Recommended if you want to log in.
  "tls"; -- Add support for secure TLS on c2s/s2s connections
  "blocklist"; -- Allow users to block communications with other users
  "bookmarks"; -- Synchronise the list of open rooms between clients
  "carbons"; -- Keep multiple online clients in sync
  "dialback"; -- Support for verifying remote servers using DNS
  "limits"; -- Enable bandwidth limiting for XMPP connections
  "pep"; -- Allow users to store public and private data in their account
  "private"; -- Legacy account storage mechanism (XEP-0049)
  "smacks"; -- Stream management and resumption (XEP-0198)
  "vcard4"; -- User profiles (stored in PEP)
  "vcard_legacy"; -- Conversion between legacy vCard and PEP Avatar, vcard
  "csi_simple"; -- Simple but effective traffic optimizations for mobile devices
  "invites"; -- Create and manage invites
  "invites_adhoc"; -- Allow admins/users to create invitations via their client
  "invites_register"; -- Allows invited users to create accounts
  "ping"; -- Replies to XMPP pings with pongs
  "register"; -- Allow users to register on this server using a client and change passwords
  "time"; -- Let others know the time here on this server
  "uptime"; -- Report how long server has been running
  "version"; -- Replies to server version requests
  "mam"; -- Store recent messages to allow multi-device synchronization
  "cloud_notify";
  "turn_external"; -- Provide external STUN/TURN service for e.g. audio/video calls
  "admin_adhoc"; -- Allows administration via an XMPP client that supports ad-hoc commands
  "admin_shell"; -- Allow secure administration via 'prosodyctl shell'
  "bosh"; -- Enable BOSH clients, aka "Jabber over HTTP"
  "websocket"; -- XMPP over WebSockets
  "announce"; -- Send announcement to all online users
  "groups"; -- Shared roster support
  "mimicking"; -- Prevent address spoofing
  "motd"; -- Send a message to users when they log in
  "proxy65"; -- Enables a file transfer proxy service which clients behind NAT can use
}
modules_disabled = {
}
s2s_secure_auth = true
limits = {
  c2s = {
    rate = "25kb/s";
  };
  s2sin = {
    rate = "100kb/s";
  };
}
pidfile = "/var/run/prosody/prosody.pid"
authentication = "internal_hashed"
archive_expires_after = "4w" -- Remove archived messages after 1 week
turn_external_host = "turn.$SERVERNAME"
turn_external_secret = "TOCHANGE"
log = {
  info = "prosody.log"; -- Change 'info' to 'debug' for verbose logging
  error = "prosody.err";
}
certificates = "/etc/prosody/certs"
https_certificate = "certs/upload.$SERVERNAME.crt"
certificates = "certs"
VirtualHost "$SERVERNAME"
  ssl = {
    key = "/etc/letsencrypt/live/$SERVERNAME/privkey.pem";
    certificate = "/etc/letsencrypt/live/$SERVERNAME/fullchain.pem";
  }
disco_items = {
  { "conference.$SERVERNAME", "Conference Server" };
}
Component "conference.$SERVERNAME" "muc"
  name = "Conference Server"
  restrict_room_creation = true
  modules_enabled = { "muc_mam", "vcard_muc" }
 Component "upload.$SERVERNAME" "http_upload"
Component "proxy.$SERVERNAME" "proxy65"
 consider_bosh_secure = true;
cross_domain_bosh = true;
https_ssl = {
  certificate = "/etc/letsencrypt/live/$SERVERNAME/fullchain.pem";
  key = "/etc/letsencrypt/live/$SERVERNAME/privkey.pem";
}
EOF
)

turnserver_conf=$(cat <<EOF
use-auth-secret
static-auth-secret=TOCHANGE
cert=/etc/letsencrypt/live/$SERVERNAME/fullchain.pem
pkey=/etc/letsencrypt/live/$SERVERNAME/privkey.pem
syslog
EOF
)

TURNPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
curl --max-time 2 http://$SERVERNAME
curl --max-time 2 http://conference.$SERVERNAME
curl --max-time 2 http://upload.$SERVERNAME
curl --max-time 2 http://proxy.$SERVERNAME
curl --max-time 2 http://turn.$SERVERNAME
certbot certonly --standalone --agree-tos --email $EMAIL --preferred-challenges http --expand --non-interactive --domain $SERVERNAME --domain conference.$SERVERNAME --domain upload.$SERVERNAME --domain proxy.$SERVERNAME --domain turn.$SERVERNAME
systemctl enable prosody
systemctl start prosody
setfacl -R -m u:prosody:rx /etc/letsencrypt/
echo "$prosody_cfg_lua" > /etc/prosody/prosody.cfg.lua
echo "$turnserver_conf" >  /etc/turnserver.conf
sed -i "s/TOCHANGE/$TURNPASSWORD/g" /etc/prosody/prosody.cfg.lua
sed -i "s/TOCHANGE/$TURNPASSWORD/g" /etc/turnserver.conf
prosodyctl --root cert import /etc/letsencrypt/live
systemctl restart prosody
systemctl restart coturn
prosodyctl check certs

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "xmpp" > "${TARGET_MARKER}.name"

exec "$@"


