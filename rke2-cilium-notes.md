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

## Install RKE2

```bash
curl -sfL https://get.rke2.io | sh -

systemctl enable rke2-server.service

systemctl start rke2-server.service &

journalctl -u rke2-server -f
```

## Make the kubeconfig usable

```bash
sudo cp /etc/rancher/rke2/rke2.yaml ~/.config/kube/rke2.yaml
sudo chown $USER:$USER ~/.config/kube/rke2.yaml
export KUBECONFIG=~/.config/kube/rke2.yaml
```

## Update Cilium for l2 advertisement, kube proxy replacement

### LoadBalanacing

Using Cilium as a Metallb replacement for l2 loadbalancing requires confiuring the following:

1. l2 Announcement docs: https://docs.cilium.io/en/stable/network/l2-announcements/
  
    - l2announcements makes loadbalancers work with local dhcp
    - kubeProxyReplacement required for l2announcements to work

2. Loadbalancer IP Address Management (LB IPAM) Docs: https://docs.cilium.io/en/stable/network/lb-ipam/
  
    - provide Ip address pools like metallb
    - cannot use /32 range because it assumed 1st and last IPs wont be used. Needs a /30 at lowest. Annoying

3. loadbalancerMode should be 'Shared' this will let ingresses use the same eternal IP, when set to 'dedicated' each ingress will spawn a new loadbalancer and require a new IP address.

4. 'externalIPs' muste be enabled and 'devices' must be set to the network adapter we will use for the loadbalancer IP assignments.

5. k8sServiceHost must be set to the address where the k8s service is available, not sure how setting thsi to the WG interface would work yet...
    
```bash
helm repo add cilium https://helm.cilium.io/
helm upgrade rke2-cilium cilium/cilium --namespace kube-system --reuse-values \
   --set l2announcements.enabled=true \
   --set kubeProxyReplacement=true \
   --set l7Proxy=true \
   --set ingressController.enabled=true \
   --set ingressController.loadbalancerMode=shared \
   --set externalIPs.enabled=true \
   --set devices=enp0s2 \
   --set k8sClientRateLimit.qps=5 \
   --set k8sClientRateLimit.burst=10 \
   --set k8sServiceHost=192.168.50.101 \
   --set k8sServicePort=6443 \
   --set operator.replicas=1
```

## enable hubble ui

```bash
helm upgrade rke2-cilium cilium/cilium \
  --version 1.14.2 \
  --namespace kube-system \
  --reuse-values \
  --set hubble.relay.enabled=true \
  --set hubble.enabled=true \
  --set hubble.ui.enabled=true

k port-forward hubble-ui-5b6f9b49cf-m72gt 30000:8081 --address 0.0.0.0
```

## Create a address adverstisement policy

```yaml
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
```

## Create a Loadbalancer IP pool

```yaml
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "main-pool"
spec:
  cidrs:
  - cidr: "192.168.50.200/30"
```

## Install Rancher and CertManager

```bash
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
```
