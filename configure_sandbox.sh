# Load variables
source set_variables.sh

# Set up sandbox
echo setting up sandbox
echo $(openssl rand -hex 32) > sandbox-token

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

cat > sandbox-deploy.yaml <<EOF
proxy: 
  secretToken: $(cat sandbox-token)
  service:
    type: ClusterIP
hub:
  baseUrl: /sandbox/
#  extraEnv:
#    GITLAB_HOST: $gitlab_host
rbac:
  enabled: true
singleuser:
  cpu:
    limit: 4
    guarantee: 0.05
  memory:
    limit: 8G
    guarantee: 512M
  profileList:
    - display_name: "Minimal environment"
      description: "To avoid too much bells and whistles: Python."
      kubespawner_override:
        image: jupyter/minimal-notebook:58169ec3cfd3
        default_url: /lab
      default: true
#    - display_name: "Jupyter with python"
#      description: "Create jupyter notebooks with the python kernel. "
#      kubespawner_override:
#        image: cityofcapetown/datascience:jupyter-k8s
#        default_url: /lab
#        pullPolicy: Always
#    - display_name: "Jupyter with R"
#      description: "Create jupyter notebooks with the R kernel. Also contains a minimal python kernel."
#      kubespawner_override:
#        image: riazarbi/r-heavy:latest
#        default_url: /lab
#        pullPolicy: Always
#    - display_name: "RStudio with R"
#      description: "RStudio development environment. Also contains a minimal python kernel."
#      kubespawner_override:
#        image: riazarbi/r-heavy:latest
#        default_url: /rstudio
#        pullPolicy: Always
#auth:
#  type: gitlab
#  gitlab:
#    clientId: $sandbox_Application_ID
#    clientSecret: $sandbox_Secret
#    callbackUrl: $sandbox_Callback_URL
#  admin:
#    users:
#      - rarbi
#      - ginngs
EOF

helm upgrade --install \
sandbox \
jupyterhub/jupyterhub \
--namespace=sandbox \
--timeout=36000 \
--version=0.9-dcde99a \
--values sandbox-deploy.yaml

cat > sandbox-proxy-public.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: sandbox
spec:
  type: ExternalName
  externalName: proxy-public.sandbox.svc.cluster.local
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: sandbox
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/rule-type: PathPrefix
spec:
  rules:
  - host:
    http:
      paths:
      - path: /sandbox
        backend:
          serviceName: sandbox
          servicePort: http
EOF

kubectl apply -f sandbox-proxy-public.yaml
