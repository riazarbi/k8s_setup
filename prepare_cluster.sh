# Load variables
source set_variables.sh

# Initialize master
printf "\n Initializing master... \n\n"
printf "\n Downloading docker images... \n\n"
sudo kubeadm config images pull
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Make master driveable from centos-master user
printf "\n Setting kubectl client in user home directory... \n\n"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "source /usr/share/bash-completion/bash_completion" >> ~/.bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc

# Set up flannel networking
printf "\n Setting up flannel networking overlay... \n\n"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/62e44c867a2846fefb68bd5f178daf4da3095ccb/Documentation/kube-flannel.yml 

# Set up cockpit-kubernetes
printf "\n Installing cockpit kubernetes addon... \n\n"
sudo yum install -y cockpit-kubernetes
sudo systemctl restart cockpit

# Create join bash script
kubeadm token create --print-join-command > kube_join_command

# Execute join bash script on each worker
printf "\n Enrolling workers... \n\n"
for worker_ip in $worker_ips
do
    printf "\n Enrolling $worker_ip... \n\n" 
    scp kube_join_command centos-master@$worker_ip:~/ 
    ssh -t centos-master@$worker_ip 'sudo bash ~/kube_join_command'
done

# Set up helm
printf "\n Setting up helm... \n\n"
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
kubectl create serviceaccount -n kube-system tiller
kubectl create clusterrolebinding tiller-binding --clusterrole=cluster-admin --serviceaccount kube-system:tiller
helm init --service-account tiller
helm repo update
