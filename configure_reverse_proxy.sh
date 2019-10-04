# Load variables
source set_variables.sh

# Set up reverse proxy
echo setting up traefik

# Creating RBAC
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

echo creating tls kubernetes secret
kubectl create secret generic \
traefik-cert \
--from-file=tls.crt \
--from-file=tls.key \
--namespace=kube-system

# Creating configmap
echo creating a traefik configmap
cat > traefik.toml <<EOF
# traefik.toml
defaultEntryPoints = ["http","https"]

[entryPoints]
  [entryPoints.http]
  address = ":80"
    [entryPoints.http.redirect]
      entryPoint = "https"
  [entryPoints.https]
  address = ":443"
    [entryPoints.https.tls]
      [[entryPoints.https.tls.certificates]]
      CertFile = "/ssl/tls.crt"
      KeyFile = "/ssl/tls.key"
EOF

kubectl create configmap traefik-conf --from-file=traefik.toml --namespace=kube-system

# Creating deployment
cat > traefik-deployment.yaml <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
---
kind: Deployment
apiVersion: apps/v1
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
      volumes:
      - name: ssl
        secret:
          secretName: traefik-cert
      - name: config
        configMap:
          name: traefik-conf
      containers:
      - image: traefik:v1.7.16
        name: traefik-ingress-lb
        imagePullPolicy: Always
        volumeMounts:
        - mountPath: "/ssl"
          name: "ssl"
        - mountPath: "/config"
          name: "config"
        ports:
        - name: http
          containerPort: 80
        - name: https
          containerPort: 443
        args:
        - --configfile=/config/traefik.toml
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
      #targetPort: 80
      name: http
    - protocol: TCP
      port: 443
      name: https
  type: LoadBalancer
EOF

kubectl apply -f traefik-deployment.yaml

# Deploying dashboard at /traefik
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
  - name: http
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
          servicePort: http
EOF

kubectl apply -f traefik-dashboard.yaml

kubectl get services --namespace kube-system

# This is an example of how to deploy a static web site. 
# It doesn't actually deploy it, just saves the deployment yaml to the master home directory.
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

#kubectl apply -f traefik-nginx.yaml
