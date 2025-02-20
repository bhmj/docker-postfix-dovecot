#!/bin/sh

# populate environment datas into config files
sed -i "s/myhostname =.*/myhostname = ${HOSTNAME:-localhost}/g" /etc/postfix/main.cf
sed -i "s/myorigin =.*/myorigin = ${HOSTNAME:-localhost}/g" /etc/postfix/main.cf
sed -i "s/mycustomnetworks =.*/mycustomnetworks = ${CUSTOM_NETWORKS:-}/g" /etc/postfix/main.cf
sed -i "s/MAX_MESSAGE_SIZE/${MAX_MESSAGE_SIZE:-512000}/g" /etc/postfix/main.cf
sed -i "s/MAX_MESSAGE_SIZE/${MAX_MESSAGE_SIZE:-512000}/g" /etc/postfix/master.cf

sed -i "s/^Socket\s+.*$//g" /etc/opendkim.conf
printf "\nAutoRestart Yes\nAutoRestartRate 10/1h\nDomain ${DOMAIN}\nSelector mail\nKeyFile /etc/opendkim/keys/${DOMAIN}.private\nSocket inet:10010@localhost\n" >> /etc/opendkim.conf
printf "SigningTable refile:/etc/opendkim/SigningTable\n" >> /etc/opendkim.conf
printf "KeyTable file:/etc/opendkim/KeyTable\n" >> /etc/opendkim.conf
printf "*@${DOMAIN} mail._domainkey.${DOMAIN}\n" > /etc/opendkim/SigningTable
printf "mail._domainkey.${DOMAIN} ${DOMAIN}:mail:/etc/opendkim/keys/${DOMAIN}.private\n" > /etc/opendkim/KeyTable

printf "\nmilter_default_action = accept\nmilter_protocol = 2\nsmtpd_milters = inet:localhost:10010\nnon_smtpd_milters = inet:localhost:10010" >> /etc/postfix/main.cf

chmod 700 /etc/opendkim/keys/${DOMAIN}.private
chown opendkim:opendkim /etc/opendkim/keys/${DOMAIN}.private

find /etc/postfix/ -type f -name '*_maps.cf' | xargs sed -i "s/user =.*/user = ${MYSQL_USER:-mail}/g"
find /etc/postfix/ -type f -name '*_maps.cf' | xargs sed -i "s/password =.*/password = ${MYSQL_PASSWORD:-mail}/g"
find /etc/postfix/ -type f -name '*_maps.cf' | xargs sed -i "s/hosts =.*/hosts = ${MYSQL_HOST:-localhost}/g"
find /etc/postfix/ -type f -name '*_maps.cf' | xargs sed -i "s/dbname =.*/dbname = ${MYSQL_DATABASE:-mail}/g"

sed -i "s/connect =.*/connect = host=${MYSQL_HOST:-localhost} dbname=${MYSQL_DATABASE:-mail} user=${MYSQL_USER:-mail} password=${MYSQL_PASSWORD:-mail}/g" /etc/dovecot/dovecot-sql.conf.ext

sed -i "s/postmaster_address =.*/postmaster_address = ${POSTMASTER:-postmaster@example.com}/g" /etc/dovecot/dovecot.conf

# start services
service syslog-ng start
        dovecot
        postfix start
        spamd &
service opendkim start &

chmod 777 /var/spool/postfix/maildrop/

tail -f /var/log/mail.log
