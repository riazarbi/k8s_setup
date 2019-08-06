
echo "enabling passwordless sudo"
echo 'centos-master ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

echo "locking down ssh"
sed -i "s/.*PubkeyAuthentication.*/PubkeyAuthentication yes/g" /etc/ssh/sshd_config
sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication no/g" /etc/ssh/sshd_config
sed -i "s/.*PermitRootLogin.*/PermitRootLogin no/g" /etc/ssh/sshd_config
service sshd restart

