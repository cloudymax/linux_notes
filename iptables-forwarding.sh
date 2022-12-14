iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.50.102:80
iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 192.168.50.102:443
iptables -t nat -A POSTROUTING -j MASQUERADE
