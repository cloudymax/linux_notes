```bash
sudo docker run -it \
   --name haproxy \
   -v $(pwd):/usr/local/etc/haproxy:ro \
   -p 80:80 \
   -p 443:443 \
   -p 8404:8404 \
   haproxytech/haproxy-alpine
```
