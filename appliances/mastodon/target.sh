#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=1

env_production=$(cat <<EOF
LOCAL_DOMAIN=$SERVERNAME

REDIS_HOST=localhost
REDIS_PORT=6379

DB_HOST=/var/run/postgresql
DB_USER=mastodon
DB_NAME=mastodon_production
DB_PASS=
DB_PORT=5432

ES_ENABLED=false
ES_HOST=localhost
ES_PORT=9200
ES_USER=elastic
ES_PASS=password

SECRET_KEY_BASE=
OTP_SECRET=

VAPID_PRIVATE_KEY=
VAPID_PUBLIC_KEY=

SMTP_SERVER=
SMTP_PORT=587
SMTP_LOGIN=
SMTP_PASSWORD=
SMTP_FROM_ADDRESS=notifications@$SERVERNAME

S3_ENABLED=false
S3_BUCKET=files.example.com
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
S3_ALIAS_HOST=files.example.com
IP_RETENTION_PERIOD=31556952
SESSION_RETENTION_PERIOD=31556952
EOF
)

systemctl start postgresql
su - postgres -c "psql -c \"CREATE USER mastodon CREATEDB;\""
echo "$env_production" >  /home/mastodon/live/.env.production
chown "mastodon:mastodon" /home/mastodon/live/.env.production
su - mastodon -c "PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" cd live && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/shims/:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" RAILS_ENV=production output=\$(RAILS_ENV=production bundle exec rake mastodon:webpush:generate_vapid_key) && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" private_key=\$(echo \"\$output\" | grep VAPID_PRIVATE_KEY | cut -d '=' -f2) && public_key=\$(echo \"\$output\" | grep VAPID_PUBLIC_KEY | cut -d '=' -f2) && sed -i \"s/VAPID_PRIVATE_KEY=/VAPID_PRIVATE_KEY=\$private_key/\" /home/mastodon/live/.env.production && sed -i \"s/VAPID_PUBLIC_KEY=/VAPID_PUBLIC_KEY=\$public_key/\" /home/mastodon/live/.env.production"
su - mastodon -c "PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" cd live && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/shims/:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" RAILS_ENV=production secret_key_base=\$(openssl rand -hex 64) && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" otp_secret=\$(openssl rand -hex 64) && sed -i \"s/SECRET_KEY_BASE=/SECRET_KEY_BASE=\$secret_key_base/\" /home/mastodon/live/.env.production && sed -i \"s/OTP_SECRET=/OTP_SECRET=\$otp_secret/\" /home/mastodon/live/.env.production"
su - mastodon -c "cd /home/mastodon/live && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/shims:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" RAILS_ENV=production ./bin/rails db:encryption:init" | grep -Eo '([A-Za-z_]+):\s+([A-Za-z0-9]+)' | awk -F': ' '{print "ACTIVE_RECORD_ENCRYPTION_" toupper($1) "=" $2}' >> /home/mastodon/live/.env.production
su - mastodon -c "PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" cd live && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/shims/:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" RAILS_ENV=production ./bin/rails db:setup && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/shims/:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" RAILS_ENV=production ./bin/rails assets:precompile"
systemctl stop nginx
curl --max-time 2 http://$SERVERNAME
certbot certonly --standalone --agree-tos --email $EMAIL --preferred-challenges http --expand --non-interactive --domain $SERVERNAME
systemctl start nginx
cp /home/mastodon/live/dist/nginx.conf /etc/nginx/sites-available/mastodon
ln -s /etc/nginx/sites-available/mastodon /etc/nginx/sites-enabled/mastodon
rm /etc/nginx/sites-enabled/default
sed -i "s/example.com/$SERVERNAME/g" /etc/nginx/sites-available/mastodon
sed -i 's/^\s*#\s*\(ssl_certificate\|ssl_certificate_key\)/\1/' /etc/nginx/sites-available/mastodon
systemctl restart nginx
cp /home/mastodon/live/dist/mastodon-*.service /etc/systemd/system/
chmod 0755 /home/mastodon
systemctl daemon-reload
systemctl enable --now mastodon-web mastodon-sidekiq mastodon-streaming
su - mastodon -c "PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" cd live/bin && PATH=\"\$HOME/.rbenv/bin:\$HOME/.rbenv/shims/:\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH\" RAILS_ENV=production ./tootctl accounts create $USERNAME --email=$USEREMAIL --role=Owner --confirmed --approve" > /root/mastodon_admin.confidential
chmod 0600 /root/mastodon_admin.confidential

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "mastodon" > "${TARGET_MARKER}.name"

exec "$@"

