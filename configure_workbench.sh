# Load variables
source set_variables.sh

# Set up workbench
echo setting up workbench
echo $(openssl rand -hex 32) > workbench-token

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

cat > workbench-deploy.yaml <<EOF
proxy: 
  secretToken: $(cat workbench-token)
  service:
    type: ClusterIP
hub:
  baseUrl: /workbench/
#  extraEnv:
#    GITLAB_HOST: $gitlab_host
rbac:
  enabled: true
singleuser:
  cpu:
    limit: 12
    guarantee: 4
  memory:
    limit: 150G
    guarantee: 4G
  storage:
    capacity: 200Gi
  profileList:
    - display_name: "Jupyter with python"
      description: "Create jupyter notebooks with the python kernel. "
      kubespawner_override:
        image: cityofcapetown/datascience:jupyter-k8s@sha256:d8f5f52d4b2cc4d96fe2b1e08a4494970cb0ea346c2$
        default_url: /lab
    - display_name: "Jupyter with R"
      description: "Create jupyter notebooks with the R kernel. Also contains a minimal python kernel."
      kubespawner_override:
        image: riazarbi/r-heavy:latest@sha256:a28d2f6576d6e7df5c546c3547aca827cb679c259868a05cb88950356d$
        default_url: /lab
    - display_name: "RStudio with R"
      description: "RStudio development environment. Also contains a minimal python kernel."
      kubespawner_override:
        image: riazarbi/r-heavy:latest@sha256:a28d2f6576d6e7df5c546c3547aca827cb679c259868a05cb88950356d$
        default_url: /rstudio
prePuller:
  continuous:
    enabled: true
cull:
  timeout: 604800
  every: 86400
#auth:
#  type: gitlab
#  gitlab:
#    clientId: $workbench_Application_ID
#    clientSecret: $workbench_Secret
#    callbackUrl: $workbench_Callback_URL
#  admin:
#    users:
#      - rarbi
#      - ginngs
#  whitelist:
#    users:
#      - rarbi
#      - ginngs
#      - ddutoit
EOF

helm upgrade --install \
workbench \
jupyterhub/jupyterhub \
--namespace=workbench \
--timeout=36000 \
--version=0.9-dcde99a \
--values workbench-deploy.yaml

cat > workbench-proxy-public.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: workbench
spec:
  type: ExternalName
  externalName: proxy-public.workbench.svc.cluster.local
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: workbench
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/rule-type: PathPrefix
spec:
  rules:
  - host: 
    http:
      paths:
      - path: /workbench
        backend:
          serviceName: workbench
          servicePort: http
EOF

kubectl apply -f workbench-proxy-public.yaml
