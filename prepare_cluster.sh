# Load variables
source set_variables.sh

# Initialize master
echo initializing master
sudo kubeadm config images pull
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Make master driveable from centos-master user
echo setting up kubectl client in home directory
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "source /usr/share/bash-completion/bash_completion" >> ~/.bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc

# Set up flannel networking
echo setting up flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/62e44c867a2846fefb68bd5f178daf4da3095ccb/Documentation/kube-flannel.yml 

# Set up cockpit-kubernetes
echo installing cockpit kubernetes
sudo yum install -y cockpit-kubernetes
sudo systemctl restart cockpit

# Create join bash script
kubeadm token create --print-join-command > kube_join_command

# Execute join bash script on each worker
echo enrolling workers
for worker_ip in $worker_ips
do
    echo Enrolling $worker_ip... 
    scp kube_join_command centos-master@$worker_ip:~/ 
    ssh -t centos-master@$worker_ip 'sudo bash ~/kube_join_command'
done

# Set up helm
echo setting up helm
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
kubectl create serviceaccount -n kube-system tiller
kubectl create clusterrolebinding tiller-binding --clusterrole=cluster-admin --serviceaccount kube-system:tiller
helm init --service-account tiller
helm repo update
