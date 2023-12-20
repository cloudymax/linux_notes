# Cilium + RKE2 Notes

![traffic drawio](https://github.com/cloudymax/linux_notes/assets/84841307/256cf1b9-6996-4ce3-9225-1fd5902aa5cf)

1. Create VM w/ public IP and install headscale
2. Create on-prem SLIRP-networking VM and install Headscale
3. setup HAproxy on both VMs to route traffic from the public-vm to the priavte-vm
4. install kubernetes on the private-vm as described below
5. use the private-vm's haproxy to point at a SLIRP ip-addess
6. set the nginx-ingress's loadbalancer to use the SLIRP-address

## Known Issues

Cilium currently requires working around bugs related to tls-certificate request creation and ingress loadbalancer ip-addresses.

  1. When creating an ingress, the route must be set to a non-working path like "/NothingToSeeHere" or the certificate challenge will fail.
  2. The LoadBalancer created for an Ingress does not recieve traffic from HAproxy properly which limits some usecases.
  3. LB-IPAM address pools cannot properly allocate a single, or non-continuous set of addresses. The pool only allows CIDR notation but ignores the first and last IP in the CIDR. Meaning taht one must use a /30 at minimum. In-practice this results in frequent misallocations. 

## Create a RKE2 config file

```bash
sudo mkdir -p /etc/rancher/rke2/
sudo nano /etc/rancher/rke2/config.yaml
```

```yaml
---
write-kubeconfig-mode: "0600"
node-label: []
cni:
  - cilium
disable:
  - rke2-canal
# Uncomment when using CIlium Ingress
#  - rke2-ingress-nginx

# Internal Network IP
node-ip: 10.0.2.15

# VPN IP Address
node-external-ip: 100.64.0.2

# Required for l2 IP Announcement
disable-kube-proxy: true
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
mkdir -p ~/.config/kube
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
Helm Chart: https://github.com/cilium/cilium/tree/v1.14.5/install/kubernetes/cilium

Current Version: 1.14.5

helm repo add cilium https://helm.cilium.io/
helm upgrade rke2-cilium cilium/cilium --namespace kube-system --reuse-values \
   --set l2announcements.enabled=true \
   --set kubeProxyReplacement=true \
   --set l7Proxy=true \
   --set ingressController.enabled=false \
   --set ingressController.loadbalancerMode=shared \
   --set externalIPs.enabled=true \
   --set devices=tailscale0 \
   --set k8sClientRateLimit.qps=5 \
   --set k8sClientRateLimit.burst=10 \
   --set k8sServiceHost=100.64.0.2 \
   --set k8sServicePort=6443 \
   --set operator.replicas=1
```

## Install CertManager

```bash
helm repo add jetstack https://charts.jetstack.io

helm install cert-manager jetstack/cert-manager --version v1.13.3 \
    --namespace cert-manager \
    --set installCRDs=true \
    --create-namespace
```

## Create a cluster-issuer

```yaml
/bin/cat << EOF > issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: admin@cloudydev.net
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx
EOF
```

## Create a address adverstisement policy

```yaml
/bin/cat << EOF > l2-policy.yaml
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: basic-policy
spec:
  interfaces:
  - tailscale0
  externalIPs: true
  loadBalancerIPs: true
EOF
```

## Create a Loadbalancer IP pool

```yaml
/bin/cat << EOF > ip-pool.yaml
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "main-pool"
spec:
  cidrs:
  - cidr: "100.64.0.2/30"
EOF
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
```

## Create an ingress for hubble

- you need to add the annotation:
- you need to use a nonworking path ie: "/no" at first to get your cert then change it back
- see https://github.com/cilium/cilium/issues/22340 for explanation

```bash
/bin/cat << EOF > hubble-ingress.yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hubble-ingress
  namespace: kube-system
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
    acme.cert-manager.io/http01-edit-in-place: "true"
spec:
  tls:
  - hosts:
    - hubble.buildstar.online
    secretName: "hubble-tls"
  ingressClassName: nginx
  rules:
  - host: hubble.buildstar.online
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hubble-ui
            port:
              number: 80
EOF
```

- After your certificate is ready, change the path in the ingress to just be "/"

## Install Rancher

```bash
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

kubectl create namespace cattle-system

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.buildstar.online \
  --set replicas=1 \
  --set bootstrapPassword=password
```

## Update Rancher Ingress

```yaml
/bin/cat << EOF > rancher-ingress.yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    acme.cert-manager.io/http01-edit-in-place: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
  name: rancher
  namespace: cattle-system
spec:
  ingressClassName: nginx
  rules:
  - host: rancher.buildstar.online
    http:
      paths:
      - backend:
          service:
            name: rancher
            port:
              number: 80
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - rancher.buildstar.online
    secretName: tls-rancher-ingress
EOF
```

## Install local-path provisioner

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
```
