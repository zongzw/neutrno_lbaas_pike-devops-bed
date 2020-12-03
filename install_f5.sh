#!/bin/bash -x

mkdir -p /stack
cd /stack

RDO_VM_IP=10.145.70.48
BIGIP_VM_IP=unknown
ADMIN_PASS=
BIGIP_ADMIN_PASS=admin

yum install -y wget

# Install Agent
wget https://github.com/F5Networks/f5-common-python/releases/download/v3.0.11/f5-sdk-3.0.11-1.el7.noarch.rpm
wget https://github.com/F5Networks/f5-icontrol-rest-python/releases/download/v1.3.2/f5-icontrol-rest-1.3.2-1.el7.noarch.rpm
wget https://github.com/F5Networks/f5-openstack-lbaasv2-driver/releases/download/v112.5.2/f5-openstack-lbaasv2-driver-112.5.2-1.el7.noarch.rpm
wget https://github.com/F5Networks/f5-openstack-agent/releases/download/v9.8.21/f5-openstack-agent-9.8.21-1.el7.noarch.rpm

RPMS=($(rpm -qa | grep ^f5-))
if [[ ${#RPMS[@]} -gt 0 ]] ; then
  systemctl stop f5-openstack-agent
  systemctl stop neutron-server
  rpm -ev ${RPMS[@]}
fi

rpm -ivh f5-*.rpm

# Configure Agent
sed -i \
  "s/^f5_agent_mode = .*/f5_agent_mode = normal/;
   s/^periodic_interval = .*/periodic_interval = 120000/;
   s/^debug = .*/debug = True/;
   s/^icontrol_hostname = .*/icontrol_hostname = ${BIGIP_VM_IP}/;
   s/^icontrol_password = .*/icontrol_password = ${BIGIP_ADMIN_PASS}/;
   s/^auth_version = .*/auth_version = v3/;
   s/^os_auth_url = .*/os_auth_url = http:\/\/${RDO_VM_IP}:35357\/v3/;
   s/^os_username = .*/os_username = admin/;
   s/^os_password = .*/os_password = ${ADMIN_PASS}/;
   s/^# cert_manager =/cert_manager =/" \
  /etc/neutron/services/f5/f5-openstack-agent.ini

# Configure Neutron
sed -i "/^\[DEFAULT\].*/ a f5_driver_perf_mode = 3" /etc/neutron/neutron_lbaas.conf
sed -i "/^#service_provider/ a service_provider = LOADBALANCERV2:F5Networks:neutron_lbaas.drivers.f5.driver_v2.F5LBaaSV2Driver:default" /etc/neutron/neutron_lbaas.conf
sed -i \
  "s/^#quota_loadbalancer = .*/quota_loadbalancer = -1/;
   s/^#quota_pool = .*/quota_pool = -1/" \
  /etc/neutron/neutron_lbaas.conf

sed -i \
  "s/^debug=False/debug=True/;
   /^service_provider/ s/^/#/;
   /^service_plugins/ s/^/#/;
   /^#service_plugins=/ a service_plugins=router,neutron_lbaas.services.loadbalancer.plugin.LoadBalancerPluginv2" \
  /etc/neutron/neutron.conf

echo "[service_auth]
auth_url=http://${RDO_VM_IP}:35357/v2.0
admin_user = admin
admin_tenant_name = admin
admin_password=${ADMIN_PASS}
auth_version = 2
insecure = true" >> /etc/neutron/neutron.conf

# Restart Service
systemctl restart neutron-server
systemctl enable f5-openstack-agent
systemctl start f5-openstack-agent
