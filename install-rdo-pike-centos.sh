echo "deltarpm=0" >> /etc/yum.conf

yum install yum-utils -y
yum install -y https://repos.fedorapeople.org/repos/openstack/EOL/openstack-pike/rdo-release-pike-1.noarch.rpm
yum-config-manager --quiet --save --setopt=openstack-pike.baseurl=http://vault.centos.org/7.6.1810/cloud/x86_64/openstack-pike/ >/dev/null

systemctl disable firewalld
systemctl stop firewalld
systemctl disable NetworkManager
systemctl stop NetworkManager
systemctl enable network
systemctl start network

yum install -y openstack-packstack python-pip
yum install -y qemu-kvm libvirt libvirt-client virt-install

systemctl start libvirtd
systemctl enable libvirtd

sudo packstack \
  --os-glance-install=y \
  --os-cinder-install=n \
  --os-manila-install=n \
  --os-swift-install=n \
  --os-ceilometer-install=n \
  --os-sahara-install=n \
  --os-trove-install=n \
  --os-ironic-install=n \
  --os-neutron-lbaas-install=y \
  --allinone
