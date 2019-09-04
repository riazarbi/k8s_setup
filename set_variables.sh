# ENVIRONMENTAL VARIABLES
# You should change ALL OF THESE to suit your environment

vm_subnet="172.29.100.32/24"
master_ip="172.29.100.2"
worker_ips="172.29.100.3 \
172.29.100.4 \
172.29.100.5 \
172.29.100.6 \
172.29.100.7 \
172.29.100.8 \
172.29.100.9 \
172.29.100.7 \
172.29.100.8 \
172.29.100.9" #one whitespace between ips please

nfs_server_ip=$master_ip
load_balancer_ip_range="172.29.100.10-172.29.100.11" #at least two ips please

# Change to "YES" if behind a corporate proxy
add_proxy="YES"
http_proxy="http://<PROXY_USERNAME><PROXY_PASSWORD>@<PROXY_URL>:<PROXY_PORT>/"
HTTP_PROXY=$http_proxy
HTTPS_PROXY=$http_proxy
https_proxy=$http_proxy
no_proxy="$master_ip,$worker_ips,127.0.0.1"
no_proxy=${no_proxy// /,}

# To set up jupyterlab oauth with local gitlab. 
# Note: you need to set up the Gitlab OAuth application first, and paste in the values from there.
gitlab_host="https://<GITLAB_URL>"

# sandbox
deploy_sandbox="YES"
# Get these from creating an OAuth application in the Gitlab admin interface
sandbox_Application_ID=a4c17clqkncpqenvcpqonvc[oqenv[onq235d5c1f64bd6d31df27d9cc3 # these are fake don't use them
sandbox_Secret=aa6496b1fce6dalvcnvc[oqwenv[qoneve96fa71e0920 # these are fake don't use them
sandbox_Callback_URL="https://<LOADBALANCER_TRAEFIK_URL>/sandbox/hub/oauth_callback"
# workbench
deploy_workbench="YES"
workbench_Application_ID=fff171f[oqnevpiwvoiwnbovbwepivbpwqievbnpqibp8764ec13ff98c51 # these are fake don't use them
workbench_Secret=ecdcd5fac51adpivnqpeivbnqpievnbpqenbivpqi47e25cb7073a # these are fake don't use them
workbench_Callback_URL="https://<LOADBALANCER_TRAEFIK_URL>/workbench/hub/oauth_callback"

# To set up distributed minio, running on all workers
# You need to generate keys beforehand and enter them here.
# Easiest way to generate keys is copy them out of the output of the following command:
# docker run -it --rm minio/minio && docker image rm minio
# minio_mounts must be min 4 drives for erasure coding, which is a prerequisite for distributed mode.
# "/data/dir{1...2}/dir{1...2}" allows us to use 1, 2, 4 or 8 drives for a single minio server by varying our mount points.
# if we are using 2TB drives, and we have 10 nodes, this gives us a max theoretical capacity of 2x8x10/2=80TB of usable space on 1:1 redundancy.
minio_key=MKQ8KVNEIVNEONVEONVTPM # these are fake don't use them
minio_secret=hnpovcnqepovnqeo[vn[qonev[nojSrulw+vhmy+g8WMXk3 # these are fake don't use them
minio_url="http://<RANDOM_WORKER_IP>:9000"
minio_mounts="/data/data{1...2}/data{1...2}/data{1...2}" # note these have three dots
minio_host_dirs="/data/minio/data{1..2}/data{1..2}/data{1..2}" # note these have two dots
