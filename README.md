# Build

```
docker build -t reverse-proxy-nginx .
```

# Run locally

```
docker run -it --rm -d -p 8080:443 --name web reverse-proxy-nginx
```

```
curl https://my-container-app.dotnet-works.com:8080
```

```
docker stop web
```

# Deploy as azure container app

https://docs.microsoft.com/en-us/azure/container-apps/get-started?tabs=bash

https://www.youtube.com/watch?v=fmGHEJL81rU

https://github.com/Azure-Samples/container-apps-store-api-microservice

Azure Containers Apps (not Azure App Services)
DAPR (https://docs.microsoft.com/en-us/azure/container-apps/connect-apps?tabs=bash)

https://www.withouttheloop.com/articles/2017-07-23-nginx-letsencrypt-azure-web-app/

https://docs.microsoft.com/en-us/azure/app-service/app-service-web-tutorial-custom-domain?tabs=wildcard%2Cazurecli

https://github.com/Azure-Samples/container-apps-store-api-microservice

```
RESOURCE_GROUP="dnw-rg" \
LOCATION="westeurope" \
CONTAINERAPPS_ENVIRONMENT="Prd"
```

```
az containerapp create \
 --name my-container-app \
 --resource-group $RESOURCE_GROUP \
 --environment $CONTAINERAPPS_ENVIRONMENT \
 --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
 --target-port 80 \
 --transport http \
 --ingress 'external' \
 --query properties.configuration.ingress.fqdn
```
