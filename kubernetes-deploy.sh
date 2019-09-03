# Get rid of pesky sudo check
sudo echo

# Load variables and check them
printf "\n !!! Loading important variables... \n\n"
sleep 1
source set_variables.sh
bash print_variables.sh

# Verify we can proceed
printf "\n !!! Do you want to proceed (y/n)? \n"
read answer
if [ "$answer" == "${answer#[Yy]}" ] ;then
    printf "Exiting... \n"
    exit 1
fi

printf "\n !!! Proceeding with install... \n"

# Create a cert if not provided
printf "\n !!! Do you want to create a self-signed tls certificate for kubernetes https ingress (y/n)? \n"
read create_cert
if [ "$create_cert" != "${create_cert#[Yy]}" ] ;then
    printf "\n !!! Creating new tls cert and key... \n"
   openssl req \
   -newkey rsa:2048 -nodes -keyout tls.key \
   -x509 -days 365 -out tls.crt
else
   printf "\n !!! Make sure you have copied a tls.key and tls.crt file to this directory. This will not be checked, it will just fail hard later and you'll have to start again. \n"
   sleep 5
fi

printf "\n !!! Setting up master... \n"

# Copy across each file
printf "\n !!! Copying across ssh keys... \n"
ssh-copy-id centos-master@$master_ip
printf "\n !!! Copying across scripts... \n"
# Config file
scp set_variables.sh centos-master@$master_ip:~/
# Configure all VMs in cluster
scp configure_vms.sh centos-master@$master_ip:~/
 # Secure each worker
 scp secure_host.sh centos-master@$master_ip:~/
 # Setup each worker
 scp vm_setup.sh centos-master@$master_ip:~/
# Prepare the master
scp prepare_cluster.sh centos-master@$master_ip:~/
# Configure the load balancer
scp configure_loadbalancer.sh centos-master@$master_ip:~/
# Configure the reverse proxy
scp tls.crt centos-master@$master_ip:~/
scp tls.key centos-master@$master_ip:~/
scp configure_reverse_proxy.sh centos-master@$master_ip:~/
# Configure the persistent storage
scp configure_persistent_storage.sh centos-master@$master_ip:~/
# Configure the jupyter sandbox
scp configure_sandbox.sh centos-master@$master_ip:~/
# Configure the jupyter workbench
scp configure_workbench.sh centos-master@$master_ip:~/
# Configure airflow
#scp configure_airflow.sh centos-master@$master_ip:~/
# Configure backups
printf "\n !!! Downloading the velero binary for manual transfer to master (proxies sometimes don't like the redirects... \n\n"
wget -q https://github.com/heptio/velero/releases/download/v1.0.0/velero-v1.0.0-linux-amd64.tar.gz
scp velero-v1.0.0-linux-amd64.tar.gz centos-master@$master_ip:~/ 
rm velero-v1.0.0-linux-amd64.tar.gz
scp configure_backups.sh centos-master@$master_ip:~/

# Automatically execute all scripts remotely
printf "\n !!! Remotely executing setup scripts... \n\n"
# Configure all VMs in cluster
ssh -t centos-master@$master_ip 'bash ~/configure_vms.sh'
# Prepare the master
ssh -t centos-master@$master_ip 'bash ~/prepare_cluster.sh'
# Pause to let helm deploy. This has caused errors in the past.
printf "\n !!! Sleeping for 10 min to let tiller pods propogate... \n"
printf "\n 10..." && sleep 60 && printf "9..."&& sleep 60 && printf "8..." && sleep 60 && printf "7..." && sleep 60 && printf "6..." && sleep 60 && printf "5..." && sleep 60 && printf "4..." && sleep 60 && printf "3..." && sleep 60 && printf "2..." && sleep 60 && printf "1... \n" && sleep 60
# Configure the load balancer
ssh -t centos-master@$master_ip 'bash ~/configure_loadbalancer.sh'
# Configure the reverse proxy
ssh -t centos-master@$master_ip 'bash ~/configure_reverse_proxy.sh'
# Configure the persistent storage
ssh -t centos-master@$master_ip 'bash ~/configure_persistent_storage.sh'
# Configure the jupyter sandbox
if [ $deploy_sandbox == "YES" ] ;then
  ssh -t centos-master@$master_ip 'bash ~/configure_sandbox.sh'
fi
# Configure the jupyter workbench
if [ $deploy_workbench == "YES" ] ;then
  ssh -t centos-master@$master_ip 'bash ~/configure_workbench.sh'
fi
# Configure airflow
#ssh -t centos-master@$master_ip 'bash ~/configure_airflow.sh'
# Configure backups
ssh -t centos-master@$master_ip 'bash ~/configure_backups.sh'

# Some nice ASCII art
printf "\n  CLUSTER DEPLOYMENT COMPLETE "
printf "\n   ̿' ̿'\̵͇̿̿\з=( ͡ °_̯͡° )=ε/̵͇̿̿/'̿'̿ ̿  \n \n"
