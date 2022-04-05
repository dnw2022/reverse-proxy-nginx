# Create default.conf file based on template
ENV_IP="20.31.24.249" \
ENV_DEFAULT_DOMAIN="proudbush-125ae8b6.westeurope.azurecontainerapps.io"

sed -r "s/__ENV_IP__/$ENV_IP/g; s/__ENV_DEFAULT_DOMAIN__/$ENV_DEFAULT_DOMAIN/g" default.conf.tpl > default.conf

# Build image
docker build -t reverse-proxy-nginx .

# Run container
docker run -it --rm -d -p 8080:80 --name nginx reverse-proxy-nginx

# Test
# Add entry in /etc//hosts:
# 127.0.0.1 my-container-app.dotnet-works.com 
# curl http://my-container-app.dotnet-works.com:8080

# Stop container (automatically removed)
# docker stop nginx