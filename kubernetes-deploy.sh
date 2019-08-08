sudo echo

printf "\n !!! Loading important variables... \n\n"
sleep 1
source set_variables.sh
bash print_variables.sh

printf "\n !!! Do you want to proceed (y/n)? \n"
read answer
if [ "$answer" == "${answer#[Yy]}" ] ;then
    printf "Exiting... \n"
    exit 1
fi

printf "\n !!! Proceeding with install... \n"
printf "\n !!! Setting up master... \n"
printf "\n !!! Downloading the velero binary for manual transfer to master (proxies sometimes don't like the redirects... \n\n"
#wget -qO velero.tar.gz https://github.com/heptio/velero/releases/download/v1.0.0/velero-v1.0.0-linux-amd64.tar.gz

printf "\n !!! Copying across ssh keys... \n"
ssh-copy-id centos-master@$master_ip
printf "\n !!! Copying across scripts... \n"
scp set_variables.sh centos-master@$master_ip:~/
scp configure_vms.sh centos-master@$master_ip:~/
 scp secure_host.sh centos-master@$master_ip:~/
 scp vm_setup.sh centos-master@$master_ip:~/
scp prepare_cluster.sh centos-master@$master_ip:~/
#scp velero.tar.gz centos-master@$master_ip:~/ && rm velero.tar.gz
scp configure_cluster.sh centos-master@$master_ip:~/

printf "\n !!! Remotely executing setup scripts... \n\n"
ssh -t centos-master@$master_ip 'bash ~/configure_vms.sh'
ssh -t centos-master@$master_ip 'bash ~/prepare_cluster.sh'
sleep 600
ssh -t centos-master@$master_ip 'bash ~/configure_cluster.sh'

