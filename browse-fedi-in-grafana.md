```
{app="ingress-nginx"} |= `modsecurity` |json | transaction_request_body != "", transaction_request_headers_host = "pizza.enby.city"  | json body="transaction.request.body"| line_format "{{.body}}" | json | object_content != "" | line_format `{"from": "{{.object_attributedTo}}", "ip": "{{.transaction_client_ip}}", "content": "{{ .object_content | replace "\"" " " }}"}` |json 
```
