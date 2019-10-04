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
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
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
helm init --service-account tiller --override spec.selector.matchLabels.'name'='tiller',spec.selector.matchLabels.'app'='helm' --output yaml | sed 's@apiVersion: extensions/v1beta1@apiVersion: apps/v1@' | kubectl apply -f -
helm repo update
kubectl --namespace=kube-system patch deployment tiller-deploy --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'
