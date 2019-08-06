source set_variables.sh

if [ $add_proxy == "YES" ] ;then
printf "Setting up yum proxy... \n"
# Change /etc/yum.conf
cat > /etc/yum.conf <<EOF
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
fi

echo adding host ip to /etc/hosts
echo $(hostname -I | cut -d" " -f 1) $(hostname) >> /etc/hosts

echo setting up docker bridge network
ip link add name docker0 type bridge
ip addr add dev docker0 172.17.0.1/16

echo disabling firewall
systemctl stop firewalld
systemctl disable firewalld

echo turning off swap
swapoff -a
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

echo turning off selinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo updating and installing convenience packages
yum -y update 
yum -y upgrade
yum install -y epel-release
yum install -y nano \
               tmux \
               cockpit \
               cockpit-storaged \
               cockpit-dashboard \
               htop \
               sos \
               nfs-utils \
               bash-completion \
               wget

echo setting up cockpit
mkdir /etc/systemd/system/cockpit.socket.d/
echo [Socket] > /etc/systemd/system/cockpit.socket.d/listen.conf
echo ListenStream= >> /etc/systemd/system/cockpit.socket.d/listen.conf
echo ListenStream=8999 >> /etc/systemd/system/cockpit.socket.d/listen.conf

echo enabling cockpit
systemctl daemon-reload
systemctl start cockpit
systemctl enable --now cockpit
systemctl enable --now cockpit.socket

echo setting up network clock
yum install -y ntp ntpdate
systemctl start ntpd
systemctl enable ntpd

echo installing docker-ce
yum remove docker \
docker-client \
docker-client-latest \
docker-common \
docker-latest \
docker-latest-logrotate \
docker-logrotate \
docker-engine

yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2

yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
yum -y update
yum install -y docker-ce-18.06.2.ce \
               cockpit-docker


mkdir /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

if [ $add_proxy == "YES" ] ;then
printf "Setting up docker proxy... \n"
# Docker use corporate proxy
cat > /etc/systemd/system/docker.service.d/http_proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=$HTTP_PROXY"
Environment="HTTPS_PROXY=$HTTPS_PROXY"
EOF
fi

echo enabling docker
systemctl daemon-reload
systemctl restart docker
systemctl enable docker
systemctl status docker

usermod -aG docker centos-master

echo creating minio setup script - will only be executed on workers
# CREATE MINIO SCRIPT
cat > minio_setup.sh <<EOF
docker run -d
--restart always \
-p 9000:9000 \
--hostname minio1 \
--name minio \
-e "MINIO_ACCESS_KEY="$minio_key \
-e "MINIO_SECRET_KEY="$minio_secret \
-v /data/minio:/data \
minio/minio server
EOF
for worker_ip in $worker_ips
do
  for minio_mount in $minio_mounts
  do
  if [ $(hostname -I | cut -d" " -f 1) == $worker_ip ]
  then
   echo http://minio1$minio_mount >> minio_setup.sh
  else
    echo http://$worker_ip$minio_mount >> minio_setup.sh
  fi
  done
done
cat minio_setup.sh | tr '\n' ' ' 2>&1 | tee minio_setup.sh

echo installing kubernetes
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

echo enabling kubelet
systemctl enable --now kubelet

echo taking care of some networking gotchas
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

lsmod | grep br_netfilter

modprobe br_netfilter

sudo sysctl net.bridge.bridge-nf-call-iptables=1

sudo systemctl restart network

printf "\n  ALL DONE WITH THIS ONE <=====> ☁ ▅▒░☼‿☼░▒▅ ☁\n \n"


