CHEF_WORKSTATION_VERSION=$1
OS_TYPE=$2
OS_VERSION=$3

echo "************************"
echo "Preflight Configuration "
echo "************************"

sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w vm.dirty_expire_centisecs=20000
sudo echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sudo echo "vm.dirty_expire_centisecs=20000" >> /etc/sysctl.conf

echo "******************************************"
echo "Downloading & Installing Chef Workstation "
echo "******************************************"

if [[ $OS_TYPE == *'ubuntu'* ]]
then
  wget https://packages.chef.io/files/stable/chef-workstation/$CHEF_WORKSTATION_VERSION/ubuntu/$OS_VERSION/chef-workstation_$CHEF_WORKSTATION_VERSION-1_amd64.deb
  sudo dpkg -i ./chef-workstation_$CHEF_WORKSTATION_VERSION-1_amd64.deb
else
  wget https://packages.chef.io/files/stable/chef-workstation/$CHEF_WORKSTATION_VERSION/el/$OS_VERSION/chef-workstation-$CHEF_WORKSTATION_VERSION-1.el$OS_VERSION.x86_64.rpm
  rpm -Uvh ./chef-workstation_$CHEF_WORKSTATION_VERSION.el$OS_VERSION-1.x86_64.rpm
fi

echo ""
echo ""
echo "*************************************"
echo "Verify Chef Workstation Installation "
echo "*************************************"
chef -v

echo ""
echo ""
echo "******************"
echo "Adjust /etc/hosts "
echo "******************"
sudo echo "10.11.12.13 server.bootstrap" >> /etc/hosts


# Make this key based going forward...
echo ""
echo ""
echo "*********************************"
echo " Adjust secure SSH Configuration "
echo "**********************************"
if [[ $OS_TYPE == *'centos'* ]]
then
  echo ""
  echo "*************************************"
  echo "Centos Machine : Allowing PasswordAuth"
  echo "*************************************"
  sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication  yes/g' /etc/ssh/sshd_config
  sudo systemctl restart sshd.service
fi

echo ""
echo ""
echo "*****************************************"
echo "Create bootstrap directory and contents. "
echo "*****************************************"
mkdir -p /home/vagrant/.chef/{certificates,config,cookbooks,data_bags,environments,roles}
cp /home/vagrant/vbox/node/config.rb /home/vagrant/.chef/
cp /home/vagrant/vbox/server/bootstrap-validator.pem /home/vagrant/.chef/
cp /home/vagrant/vbox/server/souschef-user.pem /home/vagrant/.chef/
sudo chown -R vagrant:vagrant /home/vagrant/.chef 
su -l vagrant -c "knife ssl fetch"

echo ""
echo ""
echo "***********************************************************"
echo "Download the Basline Profile and Install the Audit Cookbook"
echo "***********************************************************"
if [[ $OS_TYPE == *'ubuntu'* ]]
then
    sudo apt-get install -y git
else
    sudo yum -y install git
fi
su -l vagrant -c "git clone https://github.com/dev-sec/linux-baseline /home/vagrant/linux-baseline"
su -l vagrant -c "git clone https://github.com/chef-cookbooks/audit.git /home/vagrant/.chef/cookbooks/audit"

echo ""
echo ""
echo "**************************************************"
echo "Bootstrap the Node and Install the Audit Cookbook "
echo "**************************************************"

## SSH approach
knife bootstrap client.bootstrap -U vagrant -P vagrant --chef-license accept --sudo --yes

## chef-client firstboot.json approach
#sudo chmod +x /home/vagrant/vbox/node/firstboot.sh
#sudo /bin/bash -xev /home/vagrant/vbox/node/firstboot.sh

## cookbook upload
knife cookbook upload -ao /home/vagrant/.chef/cookbooks/ -u souschef

echo ""
echo ""
echo "********************"
echo "Run the Chef Client "
echo "********************"
chef-client -r 'recipe[audit::default]'

echo ""
echo ""
echo "***********************"
echo "Perform an Inspec Scan "
echo "***********************"
echo ""
echo "NOTE: This step will fail because you now need to move onto resolving issues with your node!"
echo ""
inspec exec linux-baseline -t ssh://vagrant@localhost:22 --password=vagrant
