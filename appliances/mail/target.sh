#!/bin/bash
TARGET_MARKER="/root/.targetonce"
TARGET_VERSION=3

postfix_main_cf=$(cat <<EOF
# See /usr/share/postfix/main.cf.dist for a commented, more complete version

# Debian specific:  Specifying a file name will cause the first
# line of that file to be used as the name.  The Debian default
# is /etc/mailname.
#myorigin = /etc/mailname

smtpd_banner = \$myhostname ESMTP \$mail_name (Ubuntu)
biff = no

# appending .domain is the MUA's job.
append_dot_mydomain = no

# Uncomment the next line to generate "delayed mail" warnings
#delay_warning_time = 4h

readme_directory = no

# See http://www.postfix.org/COMPATIBILITY_README.html -- default to 2 on
# fresh installs.
compatibility_level = 2

# TLS parameters
smtpd_tls_cert_file=/etc/letsencrypt/live/$MAILSERVER/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/$MAILSERVER/privkey.pem
smtpd_use_tls=yes
smtpd_tls_auth_only = yes
smtp_tls_security_level = may
smtpd_tls_security_level = may
smtpd_sasl_security_options = noanonymous, noplaintext
smtpd_sasl_tls_security_options = noanonymous

# Authentication
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes

# See /usr/share/doc/postfix/TLS_README.gz in the postfix-doc package for
# information on enabling SSL in the smtp client.

policyd-spf_time_limit = 3600

# Restrictions
smtpd_helo_restrictions =
        permit_mynetworks,
        permit_sasl_authenticated,
        reject_invalid_helo_hostname,
        reject_non_fqdn_helo_hostname
smtpd_recipient_restrictions =
        permit_mynetworks,
        permit_sasl_authenticated,
        reject_unauth_destination,
        reject_non_fqdn_recipient,
        reject_unknown_recipient_domain,
        reject_unlisted_recipient,
        check_policy_service unix:private/policyd-spf
smtpd_sender_restrictions =
        permit_mynetworks,
        permit_sasl_authenticated,
        reject_non_fqdn_sender,
        reject_unknown_sender_domain
smtpd_relay_restrictions =
        permit_mynetworks,
        permit_sasl_authenticated,
        defer_unauth_destination

# See /usr/share/doc/postfix/TLS_README.gz in the postfix-doc package for
# information on enabling SSL in the smtp client.

myhostname = $MAILDOMAIN
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
mydomain = $MAILDOMAIN
myorigin = \$mydomain
mydestination = localhost
relayhost =
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = all

# Handing off local delivery to Dovecot's LMTP, and telling it where to store mail
virtual_transport = lmtp:unix:private/dovecot-lmtp

# Virtual domains, users, and aliases
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf,
        mysql:/etc/postfix/mysql-virtual-email2email.cf

# Even more Restrictions and MTA params
disable_vrfy_command = yes
strict_rfc821_envelopes = yes
#smtpd_etrn_restrictions = reject
#smtpd_reject_unlisted_sender = yes
#smtpd_reject_unlisted_recipient = yes
smtpd_delay_reject = yes
smtpd_helo_required = yes
smtp_always_send_ehlo = yes
#smtpd_hard_error_limit = 1
smtpd_timeout = 30s
smtp_helo_timeout = 15s
smtp_rcpt_timeout = 15s
smtpd_recipient_limit = 40
minimal_backoff_time = 180s
maximal_backoff_time = 3h

# Reply Rejection Codes
invalid_hostname_reject_code = 550
non_fqdn_reject_code = 550
unknown_address_reject_code = 550
unknown_client_reject_code = 550
unknown_hostname_reject_code = 550
unverified_recipient_reject_code = 550
unverified_sender_reject_code = 550

# Milter configuration
milter_default_action = accept
milter_protocol = 6
smtpd_milters = local:opendkim/opendkim.sock
non_smtpd_milters = \$smtpd_milters
EOF
)


postfix_mysql_virtual_mailbox_domains=$(cat <<EOF
user = mailuser
password = mailuserpass
hosts = 127.0.0.1
dbname = mailserver
query = SELECT 1 FROM virtual_domains WHERE name='%s'
EOF
)
postfix_mysql_virtual_mailbox_maps=$(cat <<EOF
user = mailuser
password = mailuserpass
hosts = 127.0.0.1
dbname = mailserver
query = SELECT 1 FROM virtual_users WHERE email='%s'
EOF
)
postfix_mysql_virtual_alias_maps=$(cat <<EOF
user = mailuser
password = mailuserpass
hosts = 127.0.0.1
dbname = mailserver
query = SELECT destination FROM virtual_aliases WHERE source='%s'
EOF
)
postfix_mysql_virtual_email2email=$(cat <<EOF
user = mailuser
password = mailuserpass
hosts = 127.0.0.1
dbname = mailserver
query = SELECT email FROM virtual_users WHERE email='%s'
EOF
)
postfix_master_cf=$(cat <<EOF
smtp      inet  n       -       -       -       -       smtpd
  -o content_filter=spamassassin
submission inet n       -       y      -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
smtps     inet  n       -       -       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
pickup    unix  n       -       y       60      1       pickup
cleanup   unix  n       -       y       -       0       cleanup
qmgr      unix  n       -       n       300     1       qmgr
tlsmgr    unix  -       -       y       1000?   1       tlsmgr
rewrite   unix  -       -       y       -       -       trivial-rewrite
bounce    unix  -       -       y       -       0       bounce
defer     unix  -       -       y       -       0       bounce
trace     unix  -       -       y       -       0       bounce
verify    unix  -       -       y       -       1       verify
flush     unix  n       -       y       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       y       -       -       smtp
relay     unix  -       -       y       -       -       smtp
        -o syslog_name=postfix/\$service_name
showq     unix  n       -       y       -       -       showq
error     unix  -       -       y       -       -       error
retry     unix  -       -       y       -       -       error
discard   unix  -       -       y       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       y       -       -       lmtp
anvil     unix  -       -       y       -       1       anvil
scache    unix  -       -       y       -       1       scache
postlog   unix-dgram n  -       n       -       1       postlogd
maildrop  unix  -       n       n       -       -       pipe
  flags=DRXhu user=vmail argv=/usr/bin/maildrop -d \${recipient}
uucp      unix  -       n       n       -       -       pipe
  flags=Fqhu user=uucp argv=uux -r -n -z -a\$sender - \$nexthop!rmail (\$recipient)
ifmail    unix  -       n       n       -       -       pipe
  flags=F user=ftn argv=/usr/lib/ifmail/ifmail -r \$nexthop (\$recipient)
bsmtp     unix  -       n       n       -       -       pipe
  flags=Fq. user=bsmtp argv=/usr/lib/bsmtp/bsmtp -t\$nexthop -f\$sender \$recipient
scalemail-backend unix -       n       n       -       2       pipe
  flags=R user=scalemail argv=/usr/lib/scalemail/bin/scalemail-store \${nexthop} \${user} \${extension}
mailman   unix  -       n       n       -       -       pipe
  flags=FRX user=list argv=/usr/lib/mailman/bin/postfix-to-mailman.py \${nexthop} \${user}
spamassassin unix -     n       n       -       -       pipe
  user=spamd argv=/usr/bin/spamc -f -e
  /usr/sbin/sendmail -oi -f \${sender} \${recipient}
policyd-spf  unix  -       n       n       -       0       spawn
  user=policyd-spf argv=/usr/bin/policyd-spf
EOF
)
dovecot_dovecot_conf=$(cat <<EOF
!include_try /usr/share/dovecot/protocols.d/*.protocol
protocols = imap pop3 lmtp
postmaster_address = postmaster at $MAILDOMAIN
dict {
#quota = mysql:/etc/dovecot/dovecot-dict-sql.conf.ext
}
!include conf.d/*.conf
!include_try local.conf
EOF
)
dovecot_conf_d_10_mail_conf=$(cat <<EOF
mail_location = maildir:/var/mail/vhosts/%d/%n/
namespace inbox {
  inbox = yes
}
mail_privileged_group = mail
protocol !indexer-worker {
}
EOF
)
dovecot_conf_d_10_auth_conf=$(cat <<EOF
disable_plaintext_auth = yes
auth_mechanisms = plain login
!include auth-system.conf.ext
!include auth-sql.conf.ext
EOF
)
dovecot_conf_d_auth_sql_conf_ext=$(cat <<EOF
passdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}
userdb {
  driver = static
  args = uid=vmail gid=vmail home=/var/mail/vhosts/%d/%n
}
EOF
)
dovecot_dovecot_sql_conf_ext=$(cat <<EOF
driver = mysql
connect = host=127.0.0.1 dbname=mailserver user=mailuser password=mailuserpass
default_pass_scheme = SHA512-CRYPT
password_query = SELECT email as user, password FROM virtual_users WHERE email='%u';
EOF
)

dovecot_conf_d_10_master_conf=$(cat <<EOF
service imap-login {
  inet_listener imap {
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
}
service pop3-login {
  inet_listener pop3 {
  }
  inet_listener pop3s {
    port = 995
    ssl = yes
  }
}

service submission-login {
  inet_listener submission {
  }
}
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}

service imap {
}

service pop3 {
}

service submission {
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
  unix_listener auth-userdb {
    mode = 0600
    user = vmail
  }
  user = dovecot
}
service auth-worker {
  user = vmail
}
service dict {
  unix_listener dict {
  }
}
EOF
)

dovecot_conf_d_10_ssl_conf=$(cat <<EOF
ssl = required
ssl_cert = </etc/letsencrypt/live/$MAILSERVER/fullchain.pem
ssl_key = </etc/letsencrypt/live/$MAILSERVER/privkey.pem
ssl_client_ca_dir = /etc/ssl/certs
ssl_dh = </usr/share/dovecot/dh.pem
EOF
)

mail_sh=$(cat <<'EOF'
#!/bin/bash

DB_NAME="mailserver"

function add_domain() {
  read -p "Enter domain: " domain
  mysql -u root -e "INSERT INTO $DB_NAME.virtual_domains (name) VALUES ('$domain');"
  echo "Domain $domain added."
}
function del_domain() {
  read -p "Enter domain: " domain
  mysql -u root -e "DELETE FROM $DB_NAME.virtual_domains WHERE name='$domain';"
  echo "Domain $domain deleted."
}
function list_domains() {
  echo "Listing domains:"
  mysql -u root -e "SELECT * FROM $DB_NAME.virtual_domains;"
}
function add_address() {
  read -p "Enter email address: " email
  read -sp "Enter password: " password
  echo
  domain="${email#*@}"
  domain_id=$(mysql -u root -N -e "SELECT id FROM $DB_NAME.virtual_domains WHERE name='$domain';" | awk '{print $1}')
  if [ -z "$domain_id" ]; then
    echo "Domain not found. Please add the domain first."
    return
  fi
  hash=$(doveadm pw -s SHA512-CRYPT -p "$password" | cut -c 15-)
  mysql -u root -e "INSERT INTO $DB_NAME.virtual_users (domain_id, password, email) VALUES ('$domain_id', '$hash', '$email');"
  echo "Address $email added."
}

function del_address() {
  read -p "Enter email address: " email
  mysql -u root -e "DELETE FROM $DB_NAME.virtual_users WHERE email='$email';"
  echo "Address $email deleted."
}
function list_addresses() {
  echo "Listing addresses:"
  mysql -u root -e "SELECT * FROM $DB_NAME.virtual_users;"
}
function add_alias() {
  read -p "Enter alias address: " alias
  read -p "Enter recipient address: " rcpt
  domain="${alias#*@}"
  domain_id=$(mysql -u root -N -e "SELECT id FROM $DB_NAME.virtual_domains WHERE name='$domain';" | awk '{print $1}')
  if [ -z "$domain_id" ]; then
    echo "Domain not found for $alias. Please add the domain first."
    return
  fi
  mysql -u root -e "INSERT INTO $DB_NAME.virtual_aliases (domain_id, source, destination) VALUES ('$domain_id', '$alias', '$rcpt');"
  echo "Alias $alias -> $rcpt added."
}
function del_alias() {
  read -p "Enter alias address: " alias
  mysql -u root -e "DELETE FROM $DB_NAME.virtual_aliases WHERE source='$alias';"
  echo "Alias $alias deleted."
}
function list_aliases() {
  echo "Listing aliases:"
  mysql -u root -e "SELECT * FROM $DB_NAME.virtual_aliases;"
}

case $1 in
  domain)
    case $2 in
      add) add_domain ;;
      del) del_domain ;;
      list) list_domains ;;
      *) echo "Invalid command for domain" ;;
    esac
    ;;
  address)
    case $2 in
      add) add_address ;;
      del) del_address ;;
      list) list_addresses ;;
      *) echo "Invalid command for address" ;;
    esac
    ;;
  alias)
    case $2 in
      add) add_alias ;;
      del) del_alias ;;
      list) list_aliases ;;
      *) echo "Invalid command for alias" ;;
    esac
    ;;
  *)
    echo "Usage: $0 {domain|address|alias} {add|del|list} [arguments...]"
    ;;
esac
EOF
)

default_spamassassin=$(cat <<EOF
HOMEDIR="/home/spamd/"
OPTIONS="--create-prefs --max-children 5 --username spamd --helper-home-dir /home/spamd/ -s /home/spamd/spamd.log"
PIDFILE="/home/spamd/spamd.pid"
CRON=1
EOF
)

spamassassin_local_cf=$(cat <<EOF
rewrite_header Subject ***** SPAM _SCORE_ *****
report_safe 0
required_score          5.0
use_bayes   1
use_bayes_rules         1
bayes_auto_learn        1
skip_rbl_checks         0
use_razor2  0
use_dcc     0
use_pyzor   0
ifplugin Mail::SpamAssassin::Plugin::Shortcircuit
endif # Mail::SpamAssassin::Plugin::Shortcircuit
EOF
)

opendkim_conf=$(cat <<EOF
Syslog      yes
SyslogSuccess           yes
LogWhy      yes
Canonicalization        relaxed/simple
Mode        sv
SubDomains  no
OversignHeaders         From
AutoRestart         yes
AutoRestartRate     10/1M
Background          yes
DNSTimeout          5
SignatureAlgorithm  rsa-sha256
UserID      opendkim
UMask       007
Socket    local:/var/spool/postfix/opendkim/opendkim.sock
PidFile     /run/opendkim/opendkim.pid
TrustAnchorFile         /usr/share/dns/root.key
KeyTable           refile:/etc/opendkim/key.table
SigningTable       refile:/etc/opendkim/signing.table
ExternalIgnoreList  /etc/opendkim/trusted.hosts
InternalHosts       /etc/opendkim/trusted.hosts
EOF
)

opendkim_signing_table=$(cat <<EOF
*@$MAILDOMAIN	default._domainkey.$MAILDOMAIN
*@*.$MAILDOMAIN	default._domainkey.$MAILDOMAIN
EOF
)
opendkim_key_table=$(cat <<EOF
default._domainkey.$MAILDOMAIN	$MAILDOMAIN:default:/etc/opendkim/keys/$MAILDOMAIN/default.private
EOF
)

opendkim_trusted_hosts=$(cat <<EOF
127.0.0.1
localhost

.$MAILDOMAIN
EOF
)
default_opendkim=$(cat <<EOF
RUNDIR=/run/opendkim
SOCKET="local:/var/spool/postfix/opendkim/opendkim.sock"
USER=opendkim
GROUP=opendkim
PIDFILE=/run/opendkim/opendkim.pid
EXTRAAFTER=
EOF
)

spf_record=$(cat <<EOF
TXT  @   "v=spf1 mx ~all"
EOF
)


DEBIAN_FRONTEND=noninteractive
echo "postfix postfix/mailname string $MAILDOMAIN" | sudo debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | sudo debconf-set-selections
apt update
apt install -yq -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" postfix postfix-mysql postfix-policyd-spf-python opendkim opendkim-tools spamassassin spamc

certbot certonly --standalone --agree-tos --email $EMAIL --preferred-challenges http --expand --non-interactive --domain $MAILSERVER --deploy-hook "systemctl reload postfix; systemctl reload dovecot"
DBPASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c20)
echo "$DBPASSWORD" > /root/.email_db_password
chmod 600 /root/.email_db_password

mysql -u root -e "
 CREATE DATABASE mailserver;
 CREATE USER 'mailuser'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORD';
 GRANT SELECT ON mailserver.* TO 'mailuser'@'127.0.0.1';
 FLUSH PRIVILEGES;
 USE mailserver;
 CREATE TABLE virtual_domains (
   id int(11) NOT NULL auto_increment,
   name varchar(50) NOT NULL,
   PRIMARY KEY (id)
 ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
 CREATE TABLE virtual_users (
   id int(11) NOT NULL auto_increment,
   domain_id int(11) NOT NULL,
   password varchar(106) NOT NULL,
   email varchar(100) NOT NULL,
   PRIMARY KEY (id),
   UNIQUE KEY email (email),
   FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
 ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
 CREATE TABLE virtual_aliases (
   id int(11) NOT NULL auto_increment,
   domain_id int(11) NOT NULL,
   source varchar(100) NOT NULL,
   destination varchar(100) NOT NULL,
   PRIMARY KEY (id),
   FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
 ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
 INSERT INTO mailserver.virtual_domains (name) VALUES ('$MAILDOMAIN');"

echo "$postfix_main_cf" > /etc/postfix/main.cf
echo "$postfix_mysql_virtual_mailbox_domains_cf" > /etc/postfix/mysql-virtual-mailbox-domains.cf
echo "$postfix_mysql_virtual_mailbox_maps_cf" > /etc/postfix/mysql-virtual-mailbox-maps.cf   
echo "$postfix_mysql_virtual_alias_maps_cf" > /etc/postfix/mysql-virtual-alias-maps.cf  
echo "$postfix_mysql_virtual_email2email_cf" > /etc/postfix/mysql-virtual-email2email.cf
echo "$postfix_master_cf" > /etc/postfix/master.cf
sed -i "s/mailuserpass/$DBPASSWORD/g" /etc/postfix/mysql-virtual-mailbox-domains.cf
sed -i "s/mailuserpass/$DBPASSWORD/g" /etc/postfix/mysql-virtual-mailbox-maps.cf
sed -i "s/mailuserpass/$DBPASSWORD/g" /etc/postfix/mysql-virtual-alias-maps.cf
sed -i "s/mailuserpass/$DBPASSWORD/g" /etc/postfix/mysql-virtual-email2email.cf
chmod 0755 /etc/postfix/*.cf
chmod 0755 /etc/postfix
systemctl restart postfix
echo "$dovecot_dovecot_conf" > /etc/dovecot/dovecot.conf
echo "$dovecot_conf_d_10_mail_conf" > /etc/dovecot/conf.d/10-mail.conf
mkdir -p /var/mail/vhosts/$MAILDOMAIN
groupadd -g 5000 vmail
useradd -g vmail -u 5000 vmail -d /var/mail
chown -R "vmail:vmail" /var/mail
echo "$dovecot_conf_d_10_auth_conf" > /etc/dovecot/conf.d/10-auth.conf
echo "$dovecot_conf_d_auth_sql_conf_ext" > /etc/dovecot/conf.d/auth-sql.conf.ext
echo "$dovecot_dovecot_sql_conf_ext" > /etc/dovecot/dovecot-sql.conf.ext
sed -i "s/mailuserpass/$DBPASSWORD/g" /etc/dovecot/dovecot-sql.conf.ext
chown -R "vmail:dovecot" /etc/dovecot
chmod -R o-rwx /etc/dovecot
echo "$dovecot_conf_d_10_master_conf" > /etc/dovecot/conf.d/10-master.conf
echo "$dovecot_conf_d_10_ssl_conf" > /etc/dovecot/conf.d/10-ssl.conf
systemctl restart dovecot
adduser --disabled-password --gecos "" spamd
echo "$default_spamassassin" > /etc/default/spamd
echo "$spamassassin_local_cf" > /etc/spamassassin/local.cf
systemctl start spamd
systemctl enable spamd
systemctl restart postfix
gpasswd -a postfix opendkim
echo "$opendkim_conf" > /etc/opendkim.conf
mkdir /etc/opendkim
mkdir /etc/opendkim/keys
chown -R "opendkim:opendkim" /etc/opendkim
chmod go-rw /etc/opendkim/keys
echo "$opendkim_signing_table" > /etc/opendkim/signing.table
echo "$opendkim_key_table" > /etc/opendkim/key.table
echo "$opendkim_trusted_hosts" > /etc/opendkim/trusted.hosts
mkdir /etc/opendkim/keys/$MAILDOMAIN
opendkim-genkey -b 2048 -d $MAILDOMAIN -D /etc/opendkim/keys/$MAILDOMAIN -s default -v
chown "opendkim:opendkim" /etc/opendkim/keys/$MAILDOMAIN/default.private
chmod 600 /etc/opendkim/keys/$MAILDOMAIN/default.private
cp /etc/opendkim/keys/$MAILDOMAIN/default.txt /root/dkim.keys
mkdir /var/spool/postfix/opendkim
chown "opendkim:postfix" /var/spool/postfix/opendkim
echo "$default_opendkim" > /etc/default/opendkim
echo "$spf_record" > /root/spf.record
echo "$mail_sh" > /root/mail.sh
chmod u+x /root/mail.sh
systemctl restart opendkim postfix
   
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "$TARGET_VERSION" > "${TARGET_MARKER}"
chattr +i "${TARGET_MARKER}"

echo "mail" > "${TARGET_MARKER}.name"

exec "$@"
