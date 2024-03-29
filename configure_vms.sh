# Load variables
source set_variables.sh

# Lock down master ssh and enable passwordless ssh
sudo bash secure_host.sh

# Do the same for all workers.
echo "enabling passwordless sudo for workers and copying private keys"
# Generate ssh keys
ssh-keygen
for worker_ip in $worker_ips
do
    echo Setting up $worker_ip...
    ssh-copy-id centos-master@$worker_ip
    scp secure_host.sh centos-master@$worker_ip:~/
    ssh -t centos-master@$worker_ip 'sudo bash ~/secure_host.sh'
done

# Set up the master for kubernetes
sudo bash vm_setup.sh

# Set up workers for kubernetes and install minio server
for worker_ip in $worker_ips
do
    scp vm_setup.sh centos-master@$worker_ip:~/ 
    scp set_variables.sh centos-master@$worker_ip:~/ 
done

for worker_ip in $worker_ips
do
    ssh -t centos-master@$worker_ip 'sudo bash ~/vm_setup.sh' 
done

for worker_ip in $worker_ips
do
    ssh -t centos-master@$worker_ip 'sudo bash ~/minio_setup.sh' 
done
curl --head http://$minio_url/minio/health/ready

# Set up peristent storage
echo "setting up nfs storage"
sudo mkdir /data
sudo mkdir /data/nfs
sudo chown centos-master:centos-master /data/nfs

sudo sh -c 'echo  /data/nfs '$vm_subnet'\(rw\,no_root_squash\) >> /etc/exports'
sudo systemctl start rpcbind nfs-server
sudo systemctl enable rpcbind nfs-server
sudo systemctl status rpcbind nfs-server
echo nfs server ip: $nfs_server_ip

# Set up proxy for master to be able to pull from helm
if [ $add_proxy == "YES" ] ;then
printf "Setting up .bashrc proxy... \n"
echo export http_proxy=$http_proxy >> ~/.bashrc
echo export HTTP_PROXY=$HTTP_PROXY >> ~/.bashrc
echo export HTTPS_PROXY=$HTTPS_PROXY >> ~/.bashrc
echo export https_proxy=$https_proxy >> ~/.bashrc
echo export no_proxy=$no_proxy >> ~/.bashrc
echo export NO_PROXY=$no_proxy >> ~/.bashrc
fi
