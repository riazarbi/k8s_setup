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
    ssh -t centos-master@$worker_ip 'sudo bash ~/vm_setup.sh'
    ssh -t centos-master@$worker_ip 'sudo bash ~/minio_setup.sh'
done

# Set up proxy for master to be able to pull from helm
if [ $add_proxy == "YES" ] ;then
printf "Setting up .bashrc proxy... \n"
echo http_proxy=$http_proxy >> ~/.bashrc
echo HTTP_PROXY=$HTTP_PROXY >> ~/.bashrc
echo HTTPS_PROXY=$HTTPS_PROXY >> ~/.bashrc
echo https_proxy=$https_proxy >> ~/.bashrc
echo no_proxy=$no_proxy >> ~/.bashrc
fi
