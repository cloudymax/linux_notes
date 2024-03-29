# Cilium + RKE2 Notes

![traffic drawio](https://github.com/cloudymax/linux_notes/assets/84841307/256cf1b9-6996-4ce3-9225-1fd5902aa5cf)

1. Create VM w/ public IP and install headscale
2. Create on-prem SLIRP-networking VM and install Headscale
3. setup HAproxy on both VMs to route traffic from the public-vm to the priavte-vm
4. install kubernetes on the private-vm as described below
5. use the private-vm's haproxy to point at a SLIRP ip-addess
6. set the nginx-ingress's loadbalancer to use the SLIRP-address

## LoadBalanacing Notes

Using Cilium as a Metallb replacement for l2 loadbalancing requires confiuring the following:

1. l2 Announcement docs: https://docs.cilium.io/en/stable/network/l2-announcements/
  
    - l2announcements makes loadbalancers work with local dhcp
    - kubeProxyReplacement required for l2announcements to work

2. Loadbalancer IP Address Management (LB IPAM) Docs: https://docs.cilium.io/en/stable/network/lb-ipam/
    - provide Ip address pools like metallb
    - cannot use /32 range because it assumed 1st and last IPs wont be used. Needs a /30 at lowest. Annoying

3. loadbalancerMode should be 'Shared' this will let ingresses use the same eternal IP, when set to 'dedicated' each ingress will spawn a new loadbalancer and require a new IP address.

4. 'externalIPs' muste be enabled and 'devices' must be set to the network adapter we will use for the loadbalancer IP assignments.

5. k8sServiceHost must be set to the address where the k8s service is available.

## Known Issues

Cilium currently requires working around bugs related to tls-certificate request creation and ingress loadbalancer ip-addresses.

  1. When creating an ingress, the route must be set to a non-working path like "/NothingToSeeHere" or the certificate challenge will fail.
  2. The LoadBalancer created for an Ingress does not recieve traffic from HAproxy properly which limits some usecases.
  3. LB-IPAM address pools cannot properly allocate a single, or non-continuous set of addresses. The pool only allows CIDR notation but ignores the first and last IP in the CIDR. Meaning taht one must use a /30 at minimum. In-practice this results in frequent misallocations. 

## Create a Cluster

<details>
  <summary> RKE2 </summary>
  
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
# Disable rke2 bundled nginx
# fails with: docker invalid tar header: unknown
  - rke2-ingress-nginx

# Internal Network IP
node-ip: 10.0.2.15

# VPN IP Address
node-external-ip: 100.64.0.2

# Required for l2 IP Announcement
disable-kube-proxy: true
```

</details>

<details>
  <summary> K3s </summary>

## Create a K3s config file

```bash
sudo mkdir -p /etc/rancher/k3s/
sudo nano /etc/rancher/k3s/config.yaml
```

```yaml
---
write-kubeconfig-mode: "0600"
node-label: []
disable:
  - traefik
  - servicelb
  - metrics-server
secrets-encryption: true
disable-kube-proxy: true
flannel-backend: none
disable-network-policy: true
```
</details>

## Create a Cilium config file

<details>
  <summary> K3s </summary>

## Create a Cilium helm values file

```bash
nano cilium-values.yaml
```

```bash
k8sServiceHost: 168.119.173.228
k8sServicePort: 6443
kubeProxyReplacement: true
l2announcements:
  enabled: true
l7Proxy: true
ingressController:
  enabled: false
  loadbalancerMode: shared
externalIPs:
  enabled: true
devices: eth0
k8sClientRateLimit:
  qps: 5
  burst: 10
operator:
  replicas: 1
encryption:
  enabled: true
  type: wireguard
```

```bash
helm repo add cilium https://helm.cilium.io/

helm install cilium cilium/cilium -f cilium-values.yaml -n kube-system
```

</details>

<details>
  <summary> RKE2 </summary>

## Creaete a RKE2 Helm config file

```bash
sudo mkdir -p /var/lib/rancher/rke2/server/manifests/
sudo nano /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
```

```yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    k8sServiceHost: 100.64.0.2
    k8sServicePort: 6443
    kubeProxyReplacement: true
    l2announcements:
      enabled: true
    l7Proxy: true
    ingressController:
      enabled: false
      loadbalancerMode: shared
    externalIPs:
      enabled: true
    devices: tailscale0
    k8sClientRateLimit:
      qps: 5
      burst: 10
    operator:
      replicas: 1
    encryption:
      enabled: true
      type: wireguard
```
</details>


## Install K3s

```bash
curl -sfL https://get.k3s.io | sh -
```

## Make Kubceconfig usable

```bash
mkdir -p ~/.config/kube

sudo cp /etc/rancher/k3s/k3s.yaml ~/.config/kube/config

sudo chown $USER:$USER ~/.config/kube/config

export KUBECONFIG=~/.config/kube/config
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

## Validate pod-to-pod encryption

```bash
kubectl -n kube-system exec -ti ds/cilium -- bash
root@localhost:/home/cilium# cilium status | grep Encryption
```

## Install local-path provisioner

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
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

<details>
  <summary> Production Issuer </summary>

#### Production Issuer 

```yaml
/bin/cat << EOF > prod-issuer.yaml
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
          # change to 'cilium' if using a cilium ingress
          ingressClassName: nginx
EOF

kubectl apply -f prod-issuer.yaml
```
</details>
  

<details>
  <summary> Staging Issuer </summary>

#### Staging Issuer 

```yaml
/bin/cat << EOF > staging-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # The ACME server URL
    server: https://acme-staging-v02.api.letsencrypt.org/
    # Email address used for ACME registration
    email: admin@cloudydev.net
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-staging
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx
EOF

kubectl apply -f staging-issuer.yaml
```
</details>

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

kubectl apply -f l2-policy.yaml
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
  - cidr: "10.0.2.18/30"
EOF

kubectl apply -f ip-pool.yaml
```

## Install Ingress-Nginx

```bash
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml

sed -i 's/NodePort/LoadBalancer/g' deploy.yaml

kubectl apply -f deploy.yaml
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

- You need to add the annotation: `acme.cert-manager.io/http01-edit-in-place: "true"`
- You need to use a nonworking path ie: "/no" at first
- After your certificate is ready, change the path in the ingress to just be "/"
- see https://github.com/cilium/cilium/issues/22340 for explanation

<details>
  <summary> Ingress-Nginx </summary>

### Ingress-Nginx

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

kubectl apply -f hubble-ingress.yaml
```
</details>

<details>
  <summary> Cilium Ingress </summary>

### Cilium Ingress 

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
  ingressClassName: cilium
  rules:
  - host: hubble.buildstar.online
    http:
      paths:
      - path: /no
        pathType: Prefix
        backend:
          service:
            name: hubble-ui
            port:
              number: 80
EOF

kubectl apply -f hubble-ingress.yaml
```
</details>

## Install Rancher

Make a values file first.

- You will need to use a production cert or new clusters wont connect to rancher properly.
- Make sure you have installed the localPath provisioner or some other storage driver.

```bash
/bin/cat << EOF > rancher-values.yaml
---
bootstrapPassword: password
hostname: rancher.buildstar.online
replicas: -1
ingress:
  enabled: true
  extraAnnotations:
    acme.cert-manager.io/http01-edit-in-place: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  tls:
    source: letsEncrypt
letsEncrypt:
  email: admin@cloudydev.net
  ingress:
    class: nginx
EOF
```

Now install Rancher 

```bash
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --create-namespace \
  -f rancher-values.yaml
```

Edit the rancher Ingress

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rancher
  namespace: cattle-system
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # Optional vouch proxy settings
    #nginx.ingress.kubernetes.io/auth-signin: "https://vouch.buildstar.online/login?url=$scheme://$http_host$request_uri&vouch-failcount=$auth_resp_failcount&X-Vouch-Token=$auth_resp_jwt&error=$auth_resp_err"
    #nginx.ingress.kubernetes.io/auth-url: https://vouch.buildstar.online/validate
    #nginx.ingress.kubernetes.io/auth-response-headers: X-Vouch-User
    #nginx.ingress.kubernetes.io/auth-snippet: |
      #auth_request_set $auth_resp_jwt $upstream_http_x_vouch_jwt;
      #auth_request_set $auth_resp_err $upstream_http_x_vouch_err;
      #auth_request_set $auth_resp_failcount $upstream_http_x_vouch_failcount;
spec:
  tls:
    - hosts:
      - rancher.buildstar.online
      secretName: rancher-tls
  ingressClassName: nginx
  rules:
  - host: rancher.buildstar.online
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rancher
            port:
              number: 80
```

## Get an API Key

- Log in to web UI
- Click user icon in top right corner
- Click on 'Account and API Keys'
- Create a new API Key
  
## Install the RancherCLI

Releases: https://github.com/rancher/cli/releases
Docs: https://ranchermanager.docs.rancher.com/reference-guides/cli-with-rancher/rancher-cli

Install:

```bash
wget https://github.com/rancher/cli/releases/download/v2.8.0/rancher-linux-amd64-v2.8.0.tar.gz
tar xvf rancher-linux-amd64-v2.8.0.tar.gz
sudo mv rancher-v2.8.0/rancher /usr/bin/

rancher --version
$ rancher login https://rancher.buildstar.online -t <my-secret-token>
```

