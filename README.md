# Intro

At the time of writing Azure Container Apps do not support custom domains (see: https://stackoverflow.com/questions/70474387/how-to-use-a-custom-domain-with-a-azure-container-app). AGW and FrontDoor can be used, but are expensive.

One (cheap) way to get around the current limitation of not being able to use custom domains is to use an Azure (Web) App Service that acts as a reverse-proxy. Azure App Services (including Azure Container App Services) do support custom domains. In this case we use a custom nginx container.

As mentioned in the documenation, in App Services TLS termination happens at the network load balancers. That means all HTTPS requests reach the app as unencrypted HTTP requests. That's the reason the nginx default.conf file configures nginx to listen on port 80.

Every Container App that is configured to be externally accessible is made available in the following format:

https://{app_name}.{app_environment}.{region}.azurecontainerapps.io

That means we want to forward https://{app_name}.dotnet-works.com to https://{app_name}.{app_environment}.{region}.azurecontainerapps.io. Since the Azure Load Balancer terminates TLS, our nginx receives a request at http://{app_name}.dotnet-works.com. We determine the sub-domain (app-name) and use that to construct the Container App Service url. Note that the nginx upstream has a fixed ip, which is the static ip of the Azure Container App Environment (app_environment).

Some interesting things about Azure Container App Services can be read here:

https://docs.microsoft.com/en-us/archive/blogs/waws/things-you-should-know-web-apps-and-linux

# Build and run locally

```
docker build -t reverse-proxy-nginx .
```

```
docker run -it --rm -d -p 8080:80 --name nginx reverse-proxy-nginx
```

Test locally after adding a /etc/hosts entry that points my-container-app.dotnet-works.com to 127.0.0.1:

```
curl https://my-container-app.dotnet-works.com:8080
```

```
docker stop nginx
```

# Build and publish image

See ./.github/workflows/azure-app-service-dpeloy.yml

# Create the Azure App Service

Define variables:

```
RESOURCE_GROUP=dnw-rg \
SERVICE_PRINCIPAL_NAME=sp-dnw
```

Create Resource Group:

```
az group create --name $RESOURCE_GROUP --location $LOCATION
```

Create Service Principal (SP):

```
az ad sp create-for-rbac \
  --name $SERVICE_PRINCIPAL_NAME \
  --role $CONTRIBUTOR_ROLE_NAME \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth
```

The output of this command is a json object. You need to create a github secret named AZURE_CREDENTIALS and store this json object as its value to be enable continuous integration / -deployment (CI/CD).

# Setup CI/CD for Azure App Service

```
az webapp deployment container config --enable-cd true --name $APP_NAME --resource-group $RESOURCE_GROUP
```

# Custom wildcard domain and HTTPS

You need a pfx file with both public and private key. To create it from a .key and .crt file:

```
openssl pkcs12 -export -out dnw.pfx -inkey dnw.key -in dnw.crt
```

In the App Service go to Settings -> Custom Domains. Click on "Add custom domain", enter \*.dotnet-works.com and click "Validate". You probably need to add a TXT record with your DNS provider to prove you own the domain. Follow the instructions in the Azure Portal. For Hostname record type choose CNAME. Then click the "Add custom domain" button.

Under TLS/SSL settings click the "Private Key Certificates (.pfx)" tab and choose "Upload Certificate". Select dnw.pfx, enter the certificate password and click "Upload".

Go back to Settings -> Custom domain and click on the "Add binding" link behind the _.dotnet-works.com custom domain. For Private Certificate Thumbprint select _.dotnet-works.com and for TLS/SSL Type select SNI SSL. Then click "Add Binding".

# Deploy a Azure Container App to test with

```
ENVIRONMENT_NAME="Prd"

az containerapp env create \
  --name $ENVIRONMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

```
APP_NAME="my-container-app"

az containerapp create \
 --name $APP_NAME \
 --resource-group $RESOURCE_GROUP \
 --environment $CONTAINERAPPS_ENVIRONMENT \
 --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
 --target-port 80 \
 --transport http \
 --ingress 'external' \
 --query properties.configuration.ingress.fqdn
```

# Update Cloudflare DNS

Add a CNAME record:

| Type  | Name             | Content                                   |
| ----- | ---------------- | ----------------------------------------- |
| CNAME | my-container-app | reverse-proxy-nginx-dnw.azurewebsites.net |

Name here should be the name of the azure containerapp and content the url of the nginx azure webapp.

# Issues

SP has too many rights? Maybe better to create Resource Group and Container Registry (ACR) manually first?

# More resources on Azure Container Apps

https://docs.microsoft.com/en-us/azure/container-apps/get-started?tabs=bash

https://www.youtube.com/watch?v=fmGHEJL81rU

https://github.com/Azure-Samples/container-apps-store-api-microservice

Azure Containers Apps (not Azure App Services)
DAPR (https://docs.microsoft.com/en-us/azure/container-apps/connect-apps?tabs=bash)

https://www.withouttheloop.com/articles/2017-07-23-nginx-letsencrypt-azure-web-app/

https://docs.microsoft.com/en-us/azure/app-service/app-service-web-tutorial-custom-domain?tabs=wildcard%2Cazurecli

https://github.com/Azure-Samples/container-apps-store-api-microservice
