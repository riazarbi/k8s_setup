# Load variables
source set_variables.sh

# Set up load balancer
echo setting up load balancer
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.1/manifests/metallb.yaml

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
      # must be 2 or greater
      - $load_balancer_ip_range
EOF

kubectl apply -f metallb.yaml
