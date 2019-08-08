# Load variables
source set_variables.sh

# Set up load balancer
echo setting up load balancer
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml

cat > metallb.yaml <<EOF
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

kubectl apply -f metallb.yaml

# Set up reverse proxy
echo setting up traefik
cat > traefik-rbac.yaml <<EOF
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
- kind: ServiceAccount
  name: traefik-ingress-controller
  namespace: kube-system
EOF

kubectl apply -f traefik-rbac.yaml

cat > traefik-deployment.yaml <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress-lb
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: traefik-ingress-lb
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress-lb
        name: traefik-ingress-lb
    spec:
      serviceAccountName: traefik-ingress-controller
      terminationGracePeriodSeconds: 60
      containers:
      - image: traefik
        name: traefik-ingress-lb
        ports:
        - name: http
          containerPort: 80
        - name: admin
          containerPort: 8080
        args:
        - --api
        - --kubernetes
        - --logLevel=INFO
---
kind: Service
apiVersion: v1
metadata:
  name: traefik-ingress-service
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
    - protocol: TCP
      # this is the port traefik listens on. Change to 80 if you want to listen on 80.
      port: 80
      # this is the port traefik sends traffic to
      targetPort: 80
      name: web
    - protocol: TCP
      port: 8080
      name: admin
  type: LoadBalancer
EOF

kubectl apply -f traefik-deployment.yaml

cat > traefik-dashboard.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: traefik-web-ui
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
  - name: web
    port: 80
    targetPort: 8080
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-web-ui
  namespace: kube-system
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/rule-type: PathPrefixStrip
spec:
  rules:
  - host:
    http:
      paths:
      - path: /traefik
        backend:
          serviceName: traefik-web-ui
          servicePort: web
EOF

kubectl apply -f traefik-dashboard.yaml

kubectl get services --namespace kube-system

cat > traefik-nginx.yaml <<EOF
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: sample-wui
  labels:
    app: sample-wui
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-wui
  template:
    metadata:
      labels:
        app: sample-wui
    spec:
      containers:
      - name: docker-wui
        image: docker.io/cityofcapetown/docker_wui:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: sample-wui
spec:
  ports:
  - name: http
    targetPort: 80
    port: 80
  selector:
    app: sample-wui
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: sample-wui
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/rule-type: PathPrefixStrip

spec:
  rules:
  - host:
    http:
      paths:
      - path: /sample-wui
        backend:
          serviceName: sample-wui
          servicePort: http
EOF

kubectl apply -f traefik-nginx.yaml

echo setting up nfs-backed volume provisioner
helm install stable/nfs-client-provisioner \
  --set nfs.server=$nfs_server_ip \
  --set nfs.path=/data/nfs  \
  --set replicaCount=2 \
  --name nfs-client \
 --set storageClass.defaultClass=true

# Set up jupyterhub
echo setting up jupyterhub
echo $(openssl rand -hex 32) > jupyterhub-token

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

cat > jupyterhub-deploy.yaml <<EOF
proxy: 
  secretToken: $(cat jupyterhub-token)
  service:
    type: ClusterIP
hub:
  baseUrl: /jupyter/
#  extraEnv:
#    GITLAB_HOST: $gitlab_host
rbac:
  enabled: true
singleuser:
  profileList:
    - display_name: "Minimal environment"
      description: "To avoid too much bells and whistles: Python."
      kubespawner_override:
        image: jupyter/minimal-notebook:58169ec3cfd3
        default_url: /lab
      default: true
#    - display_name: "Datascience environment"
#      description: "If you want the additional bells and whistles: Python, R, and Julia."
#      kubespawner_override:
#        image: jupyter/datascience-notebook:2343e33dec46
#        default_url: /lab
#    - display_name: "Spark environment"
#      description: "The Jupyter Stacks spark image!"
#      kubespawner_override:
#        image: jupyter/all-spark-notebook:2343e33dec46
#        default_url: /lab
#    - display_name: "CoCT Jupyter environment"
#      description: "The image with all the things. Starts into jupyterlab. Should we start into classic mode instead?"
#      kubespawner_override:
#        image: cityofcapetown/datascience:jupyter-k8s
#        default_url: /lab
#    - display_name: "CoCT RStudio environment"
#      description: "Yes, RStudio works too!"
#      kubespawner_override:
#        image: cityofcapetown/datascience:rsession-k8s
#        default_url: /rstudio
#auth:
#  type: gitlab
#  gitlab:
#    clientId: $Application_ID
#    clientSecret: $Secret
#    callbackUrl: $Callback_URL
#prePuller:
#  continuous:
#    enabled: true
EOF

helm upgrade --install jupyterhub jupyterhub/jupyterhub \
   --namespace=jupyterhub \
   --timeout=36000 \
   --version=0.9-dcde99a \
   --values jupyterhub-deploy.yaml
# or 0.9-dcde99a 11 Jul 2019

cat > jupyterhub-proxy-public.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: jupyter
spec:
  type: ExternalName
  externalName: proxy-public.jupyterhub.svc.cluster.local
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: jupyter
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/rule-type: PathPrefix
spec:
  rules:
  - host: 
    http:
      paths:
      - path: /jupyter
        backend:
          serviceName: jupyter
          servicePort: http
EOF

kubectl apply -f jupyterhub-proxy-public.yaml

# Set up backups
echo setting up backups
mkdir ~/bin
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
mv mc ~/bin
#mc config host add edge $minio_url $minio_key $minio_secret
#mc mb edge/kubernetes-volumes
#mc mb edge/kubernetes-configs

tar -xvf velero.tar.gz 
mv velero-v1.0.0-linux-amd64/velero ~/bin/velero 
rm -rf velero-v1.0.0-linux-amd64 
rm velero.tar.gz

cat > credentials-velero <<EOF
[default]
aws_access_key_id = $minio_key
aws_secret_access_key = $minio_secret
EOF

#velero install \
#    --provider aws \
#    --bucket kubernetes-configs \
#    --secret-file ./credentials-velero \
#    --use-volume-snapshots=false \
#    --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=$minio_url

## Backing up
#velero backup create kubernetes-configs
#tar -zcvf latest-nfs.tar.gz /data/nfs
#mc cp latest-nfs.tar.gz edge/kubernetes-volumes/$(date '+%Y-%m-%d')-nfs.tar.gz
#mc cp edge/kubernetes-volumes/$(date '+%Y-%m-%d')-nfs.tar.gz edge/kubernetes-volumes/latest-nfs.tar.gz
#rm latest-nfs.tar.gz

## Restoring
# best way to restore is restore a VM snapshot, but if that's not an option you can try restore from the velero backup
#mc cp edge/kubernetes-volumes/latest-nfs.tar.gz ~/
#tar -xvf ~/latest-nfs.tar.gz
#cp -r data/nfs/* /data/nfs/
#rm -rf data
#velero restore create --from-backup kubernetes-configs
#velero restore get
#rm latest-nfs.tar.gz
#reboot
# even now you may run into errors and need to manually reapply some configs...

printf "\n  CLUSTER DEPLOYMENT COMPLETE "
printf "\n   ̿' ̿'\̵͇̿̿\з=( ͡ °_̯͡° )=ε/̵͇̿̿/'̿'̿ ̿  \n \n"
