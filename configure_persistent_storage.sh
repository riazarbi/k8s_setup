# Load variables
source set_variables.sh

echo setting up nfs-backed volume provisioner
helm install stable/nfs-client-provisioner \
  --set nfs.server=$nfs_server_ip \
  --set nfs.path=/data/nfs  \
  --set replicaCount=2 \
  --name nfs-client \
 --set storageClass.defaultClass=true
