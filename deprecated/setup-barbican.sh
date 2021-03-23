#!/bin/bash

# this script can only be used as barbican setup in **** Pike OpenStack all-in-one ****.

mariadb_password=4c9a8501c4344bf1
barbican_db_password=barbican_password
barbican_user_password=barbican_password
openrc=keystonerc_admin
controller_host=10.145.73.123

echo "CREATE DATABASE if not exists barbican;" | mysql -u root -p$mariadb_password
echo "GRANT ALL PRIVILEGES ON barbican.* TO 'barbican'@'localhost' IDENTIFIED BY '$barbican_db_password';" | mysql -u root -p$mariadb_password
echo "GRANT ALL PRIVILEGES ON barbican.* TO 'barbican'@'%' IDENTIFIED BY '$barbican_db_password';" | mysql -u root -p$mariadb_password

echo "select host, user, password from mysql.user;" | mysql -u root -p$mariadb_password | grep barbican

source $openrc
openstack user create --domain default --password $barbican_user_password --or-show barbican
openstack role add --project services --user barbican admin
openstack role create creator --or-show
openstack role add --project services --user barbican creator
openstack service list | grep "key-manager"
if [ $? -ne 0 ]; then
    openstack service create --name barbican --description "Key Manager" key-manager
fi

openstack endpoint list | grep key-manager
if [ $? -ne 0 ]; then
    openstack endpoint create --region RegionOne key-manager public http://$controller_host:9311
    openstack endpoint create --region RegionOne key-manager internal http://$controller_host:9311
    openstack endpoint create --region RegionOne key-manager admin http://$controller_host:9311
fi

yum install -y openstack-barbican-api

cp /etc/barbican/barbican.conf /etc/barbican/barbican.conf.save-`date +%Y%m%d_%H%M%S`

cat << EOF > /etc/barbican/barbican.conf

[DEFAULT]
sql_connection = mysql+pymysql://barbican:$barbican_db_password@$controller_host/barbican
db_auto_create = False
transport_url=rabbit://guest:guest@$controller_host:5672/

[certificate]

[certificate_event]

[cors]

[crypto]

[dogtag_plugin]

[keystone_authtoken]

auth_uri = http://$controller_host:5000
auth_url = http://$controller_host:35357
memcached_servers = $controller_host:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = services
username = barbican
password = $barbican_user_password

[keystone_notifications]

[kmip_plugin]

[matchmaker_redis]

[oslo_messaging_amqp]


[oslo_messaging_kafka]

[oslo_messaging_notifications]

[oslo_messaging_rabbit]

[oslo_messaging_zmq]

[oslo_middleware]

[oslo_policy]

[p11_crypto_plugin]

[queue]

[quotas]

[retry_scheduler]

[secretstore]

[simple_crypto_plugin]

[snakeoil_ca_plugin]

[ssl]

EOF

su -s /bin/sh -c "barbican-manage db upgrade" barbican

yum install -y python-devel.x86_64
yum install -y python-pip
yum install -y gcc
pip install uwsgi

pids=`ps -ef | grep barbican | grep -v grep | tr -s ' ' | cut -d ' ' -f 2`
if [ -n "$pids" ]; then kill -9 $pids; fi

uwsgi --master --emperor /etc/barbican/vassals --daemonize /var/log/barbican.log
