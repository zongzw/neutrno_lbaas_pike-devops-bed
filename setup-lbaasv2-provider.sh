#!/bin/bash

workdir=`cd $(dirname $0); pwd`
mkdir -p $workdir/tmp

(
    cd $workdir/tmp

    rpm -qa | grep f5-sdk
    if [ $? -ne 0 ]; then
        echo "F5 sdk is not installed, installing ..."
        wget https://github.com/F5Networks/f5-common-python/releases/download/v3.0.11/f5-sdk-3.0.11-1.el7.noarch.rpm
        rpm -ivh f5-sdk-3.0.11-1.el7.noarch.rpm
    fi

    rpm -qa | grep f5-icontrol-rest
    if [ $? -ne 0 ]; then
        echo "F5 icontrol-rest is not installed, installing ..."
        wget https://github.com/F5Networks/f5-icontrol-rest-python/releases/download/v1.3.2/f5-icontrol-rest-1.3.2-1.el7.noarch.rpm
        rpm -ivh f5-icontrol-rest-1.3.2-1.el7.noarch.rpm
    fi


    rpm -qa | grep f5-openstack-lbaasv2-driver
    if [ $? -ne 0 ]; then
        echo "F5 driver is not installed, installing ..."
        wget https://github.com/F5Networks/f5-openstack-lbaasv2-driver/releases/download/v112.5.2/f5-openstack-lbaasv2-driver-112.5.2-1.el7.noarch.rpm
        rpm -ivh f5-openstack-lbaasv2-driver-112.5.2-1.el7.noarch.rpm
    fi


    rpm -qa | grep f5-openstack-agent
    if [ $? -ne 0 ]; then
        echo "F5 agent is not installed, installing ..."
        wget https://github.com/F5Networks/f5-openstack-agent/releases/download/v9.8.21/f5-openstack-agent-9.8.21-1.el7.noarch.rpm
        rpm -ivh f5-openstack-agent-9.8.21-1.el7.noarch.rpm
    fi
)




provider_name=CORE
agent_config_file=/etc/neutron/services/f5/f5-openstack-agent-$provider_name.ini
cat << EOF > /etc/systemd/system/f5-openstack-agent-$provider_name.service
[Unit]
Description=F5 LBaaSv2 BIG-IP Agent
After=syslog.target network.target
Requires=network.target

[Service]
User=neutron
ExecStart=/usr/bin/f5-oslbaasv2-agent --log-file /var/log/neutron/f5-openstack-agent-$provider_name.log --config-file /etc/neutron/neutron.conf --config-file $agent_config_file
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload


if [ ! -f $agent_config_file ]; then
    cp /etc/neutron/services/f5/f5-openstack-agent.ini $agent_config_file
fi

sed -i '/agent_id/s/agent_id =.*/agent_id = POD_'$provider_name'/' $agent_config_file
sed -i '/environment_prefix/environment_prefix = .*/environment_prefix = '$provider_name'' $agent_config_file

neutron.conf 

[DEFAULT]

# The service plugins Neutron will use (list value)
#service_plugins =
service_plugins = router,qos,trunk,neutron_lbaas.services.loadbalancer.plugin.LoadBalancerPluginv2,neutron.services.firewall.fwaas_plugin.FirewallPlugin

neutron_lbaas.conf
[DEFAULT]

#
# From neutron.lbaas
#

# Driver to use for scheduling to a default loadbalancer agent (string value)
#loadbalancer_scheduler_driver = neutron_lbaas.agent_scheduler.ChanceScheduler

# Automatically reschedule loadbalancer from offline to online lbaas agents.
# This is only supported for drivers who use the neutron LBaaSv2 agent (boolean
# value)
#allow_automatic_lbaas_agent_failover = false

f5_driver_perf_mode = 3

[service_providers]

#
# From neutron.lbaas
#

# Defines providers for advanced services using the format:
# <service_type>:<name>:<driver>[:default] (multi valued)
# service_provider =
# service_provider = LOADBALANCERV2:F5Networks:neutron_lbaas.drivers.f5.driver_v2.F5LBaaSV2Driver:default
service_provider=LOADBALANCERV2:DMZ:neutron_lbaas.drivers.f5.v2_DMZ.DMZ
service_provider=LOADBALANCERV2:CORE:neutron_lbaas.drivers.f5.v2_CORE.CORE:default


/usr/lib/python2.7/site-packages/neutron_lbaas/drivers/f5

cat << EOF > /usr/lib/python2.7/site-packages/neutron_lbaas/drivers/f5/v2_$provider_name.py
#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2014-2016 F5 Networks Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

from neutron_lbaas.drivers.f5.driver_v2 import F5LBaaSV2Driver


class MY_PROVIDER_ENV_NAME(F5LBaaSV2Driver):
    """Plugin Driver for $provider_name environment."""
    def __init__(self, plugin):
        super(MY_PROVIDER_ENV_NAME, self).__init__(plugin, self.__class__.__name__)

EOF

sed -i '/MY_PROVIDER_ENV_NAME/s/MY_PROVIDER_ENV_NAME/'$provider_name'/'