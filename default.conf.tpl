upstream container_app_env {
  server __ENV_IP__:443;
  keepalive 1000;
}

server {
  server_name "~(.*).dotnet-works.com";
  listen 80;
  return 301 https://$host$request_uri;

  location / {
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $1.__ENV_DEFAULT_DOMAIN__;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_ssl_session_reuse off;
    proxy_pass https://container_app_env;
    proxy_ssl_name $1.__ENV_DEFAULT_DOMAIN__;
    proxy_ssl_server_name on;
    proxy_redirect off;
    proxy_http_version 1.1;
  }
}