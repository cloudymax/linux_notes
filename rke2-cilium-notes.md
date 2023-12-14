# Using Cilium with RKE2 for LoadBalancing and Ingress

Helm Chart: https://github.com/cilium/cilium/tree/v1.14.5/install/kubernetes/cilium
Current Version: 1.14.5

## Create a RKE2 config file

```bash
sudo mkdir -p /etc/rancher/rke2/
sudo nano /etc/rancher/rke2/config.yaml
```

```yaml
---
write-kubeconfig-mode: "0644"
disable-kube-proxy: true
node-label:
  - "name=bradley"
  - "gpus=true"
cni:
  - cilium
disable:
  - rke2-canal
  - rke2-ingress-nginx
node-ip: 192.168.50.100
node-external-ip: 10.2.0.3
```

# Install RKE2

```bash
curl -sfL https://get.rke2.io | sh -

systemctl enable rke2-server.service

systemctl start rke2-server.service &

journalctl -u rke2-server -f
```

## make the kubeconfig usable

```bash
sudo cp /etc/rancher/rke2/rke2.yaml ~/.config/kube/rke2.yaml
sudo chown $USER:$USER ~/.config/kube/rke2.yaml
export KUBECONFIG=~/.config/kube/rke2.yaml
```

## Update Cilium for l2 advertisement, kube proxy replacement

```bash
helm upgrade rke2-cilium cilium/cilium --namespace kube-system --reuse-values \
   --set l2announcements.enabled=true \
   --set kubeProxyReplacement=true \
   --set l7Proxy=true \
   --set ingressController.enabled=true \
   --set ingressController.loadbalancerMode=dedicated \
   --set externalIPs.enabled=true \
   --set devices=br0 \
   --set k8sClientRateLimit.qps=100 \
   --set k8sClientRateLimit.burst=150 \
   --set k8sServiceHost=192.168.50.101 \
   --set k8sServicePort=6443
```

# enable hubble ui
helm upgrade rke2-cilium cilium/cilium --version 1.14.2 --namespace kube-system --reuse-values --set hubble.relay.enabled=true --set hubble.enabled=true --set hubble.ui.enabled=true

# expose the ui
k port-forward hubble-ui-5b6f9b49cf-m72gt 30000:8081 --address 0.0.0.0


# Create a address adverstisement policy
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: basic-policy
spec:
  interfaces:
  - br0
  externalIPs: true
  loadBalancerIPs: true


# Create a Loadbalancer IP pool
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "main-pool"
spec:
  cidrs:
  - cidr: "192.168.50.200/30"


helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

kubectl create namespace cattle-system
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io

helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=192.168.50.202.sslip.io \
  --set replicas=1 \
  --set bootstrapPassword=password
