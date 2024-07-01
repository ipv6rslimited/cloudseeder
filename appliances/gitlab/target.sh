#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=2

sed -i "/^# nginx\['listen_addresses'\] = \['\*', '\[::\]'\]/s/^# //" /etc/gitlab/gitlab.rb
sed -i "s|external_url .*|external_url 'https://$SERVERNAME'|g" /etc/gitlab/gitlab.rb
sed -i "s|# letsencrypt\['contact_emails'\] = \[\]|letsencrypt['contact_emails'] = ['$EMAIL']|g" /etc/gitlab/gitlab.rb
curl -4 --max-time 2 http://$SERVERNAME
gitlab-ctl reconfigure

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

exec "$@"


 
