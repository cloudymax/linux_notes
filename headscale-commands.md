# Headscale

wget https://github.com/juanfont/headscale/releases/download/v0.22.3/headscale_0.22.3_linux_amd64.deb
sudo apt-get install -f ./headscale_0.22.3_linux_amd64.deb

config:

```yaml
    ---
    server_url: {{ .Values.server_url }}
    listen_addr: {{ .Values.listen_addr }}
    metrics_listen_addr: {{ .Values.metrics_listen_addr }}
    private_key_path: /var/lib/headscale/private.key
    noise:
      private_key_path: /var/lib/headscale/noise_private.key
    ip_prefixes:
      - 100.64.0.0/10
    disable_check_updates: true
    db_type: sqlite3
    db_path: /var/lib/headscale/db.sqlite
    tls_cert_path: ""
    tls_key_path: ""
    log:
      format: text
      level: debug
    dns_config:
      override_local_dns: true
      nameservers:
        - 1.1.1.1
        - 1.0.0.1
      magic_dns: true
      base_domain: buildstar.online
    logtail:
      enabled: false
```
headscale user create max

headscale --user max preauthkeys create --expiration 60m

curl -fsSL https://tailscale.com/install.sh | sh

sudo tailscale up --login-server https://hs.buildstar.online:8080 --authkey 



