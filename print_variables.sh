source set_variables.sh

# Print the vars, eyeball them...
printf "\n !!! This is the IP address of the master node: \n"
echo $master_ip

printf "\n !!! These are the IP addresses of the worker nodes: \n"
for worker_ip in $worker_ips
do
    echo $worker_ip
done

printf "\n !!! The NFS server will share on this subnet: \n"
sudo sh -c 'echo  /data/nfs '$vm_subnet' \(rw\,no_root_squash\)'

printf "\n !!! Script assumes that the NFS server is on the master."
printf "\n     This is the helm script that will be run: \n"
echo helm install stable/nfs-client-provisioner \
  --set nfs.server=$nfs_server_ip \
  --set nfs.path=/data/nfs  \
  --name nfs-client \
 --set storageClass.defaultClass=true

printf "\n !!! This is the config that will be applied to the load balancer: \n"
cat > tmp <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $load_balancer_ip_range
EOF
cat tmp

if [ $add_proxy == "YES" ] ;then
# Docker proxy variables
printf "\n !!! These are the docker proxy settings that will be applied: \n"
cat > tmp <<EOF
[Service]
Environment="HTTP_PROXY=$HTTP_PROXY"
Environment="HTTPS_PROXY=$HTTPS_PROXY"
EOF
cat tmp

printf "\n !!! These are the yum repo proxy settings that will be applied: \n"
cat > tmp <<EOF
[main]
cachedir=/var/cache/yum/$basearch/$releasever
keepcache=0
debuglevel=2
logfile=/var/log/yum.log
exactarch=1
obsoletes=1
gpgcheck=1
plugins=1
installonly_limit=5
bugtracker_url=http://bugs.centos.org/set_project.php?project_id=23&ref=http://bugs.centos.org/bug_report_page.php?category=yum distroverpkg=centos-release
proxy=$HTTP_PROXY
EOF
cat tmp

printf "\n !!! These are the system proxy settings that will be added to the master ~.bashrc: \n"
echo http_proxy=$http_proxy 
echo HTTP_PROXY=$HTTP_PROXY 
echo HTTPS_PROXY=$HTTPS_PROXY 
echo https_proxy=$https_proxy 
echo no_proxy=$no_proxy

fi
rm tmp
