# ENVIRONMENTAL VARIABLES
# You should change ALL OF THESE to suit your environment

vm_subnet="192.168.101.0/24"
master_ip="192.168.101.93"
worker_ips="192.168.101.94 192.168.101.95"

nfs_server_ip=$master_ip
load_balancer_ip_range="192.168.101.85-192.168.101.89"

# Change to "YES" if behind a corporate proxy
add_proxy="NO"
#http_proxy="http://username:password@proxy_url:port/"
#HTTP_PROXY=$http_proxy
#HTTPS_PROXY=$http_proxy
#https_proxy=$http_proxy
#no_proxy="$master_ip,$worker_ips,127.0.0.1"

# To set up jupyterlab oauth with local gitlab. 
# Note: you need to set up the Gitlab OAuth application first, and paste in the values from there.
#gitlab_host="https://gitlab_url"
# Get these from creating an OAuth application in the Gitlab admin interface
#Application_ID=skdhswdhpwodhpowdpqdjwq7d398c793d21651a33
#Secret=b453aa1cf65bd844111210a9a85f3302092837478382882645a224074e
#Callback_URL="http://192.168.101.85:8000/jupyterhub/hub/oauth_callback"

# To set up distributed minio, running on all workers
# You need to generate keys beforehand and enter them here.
# Easiest way to generate keys is copy them out of the output of the following command:
# docker run -it --rm minio/minio && docker image rm minio
# minio_mounts must be min 4 drives for erasure coding, which is a prerequisite for distributed mode.
minio_mounts="/data/dir{1...4}"
minio_key=IZ9FDWEIW9YR26SXX0B9
minio_secret=qnXvUq1vYS5emmstMFguVYoSN7JDWm5kxBn+cxOD
minio_url="192.168.101.94:9000"
