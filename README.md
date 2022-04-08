# Intro

At the time of writing Azure Container Apps do not support custom domains (see: https://stackoverflow.com/questions/70474387/how-to-use-a-custom-domain-with-a-azure-container-app). AGW and FrontDoor can be used, but are expensive.

One (cheap) way to get around the current limitation of not being able to use custom domains is to use an Azure (Web) App Service that acts as a reverse-proxy. Azure App Services (including Azure Web App Services) do support custom domains. In this case we use a custom nginx container as the reverse proxy.

As mentioned in the documenation, in App Services TLS termination happens at the network load balancers. That means all HTTPS requests reach the app as unencrypted HTTP requests. That's the reason the nginx default.conf file configures nginx to listen on port 80 instead of 443.

Every Azure Container App that is configured to be externally accessible is automatically made available in Azure with the following format:

https://{app_name}.{app_environment}.{region}.azurecontainerapps.io

That means we want to forward https://{app_name}.dotnet-works.com to https://{app_name}.{app_environment}.{region}.azurecontainerapps.io. Since the Azure Load Balancer terminates TLS, our nginx receives a request at http://{app_name}.dotnet-works.com. We determine the sub-domain (app-name) and use that to construct the Azure Container App Service url. Note that the nginx upstream has a fixed ip, which is the static ip of the Azure Container App Environment (app_environment).

Some interesting things about Azure Container App Services can be read here:

https://docs.microsoft.com/en-us/archive/blogs/waws/things-you-should-know-web-apps-and-linux

# Build and run locally

Run ./run_local.sh

Test locally after adding a /etc/hosts entry that points my-container-app.dotnet-works.com to 127.0.0.1 with:

```
curl https://my-container-app.dotnet-works.com:8080
```

```
docker stop nginx
```

# Azure Deployment

./.github/workflows/azure-app-service-deploy.yml does everything except for creating a Resource Group (RG) and a Service Pincipal (SP). It also needs a base64 encoded certificate (pfx format).

You can create the RG and SP in the Azure Portal or use the az cli tool. Below commands use the az cli tool:

Define variables:

```
RESOURCE_GROUP=dnw-rg \
SERVICE_PRINCIPAL_NAME=sp-dnw \
LOCATION=westeurope
```

Create Resource Group:

```
az group create --name $RESOURCE_GROUP --location $LOCATION
```

Create Service Principal (SP):

```
az ad sp create-for-rbac \
  --name $SERVICE_PRINCIPAL_NAME \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth
```

The output of this command is a json object. You need to create a github secret named AZURE_CREDENTIALS and store this json object as its value to be enable continuous integration / -deployment (CI/CD).

# Custom wildcard domain and HTTPS

./.github/workflows/azure-app-service-deploy.yml does everything for you during deployment, but needs a secret named WILDCARD_PFX_BASE64 containing the base64 encoded certificate containing both public- and private key.

To create a base64 encoded string from the pfx file:

```
cat dnw.pfx | base64
```

To create a pfx file from a .key and .crt file:

```
openssl pkcs12 -export -out dnw.pfx -inkey dnw.key -in dnw.crt
```

# Update Cloudflare DNS

Add a CNAME record:

| Type  | Name             | Content                                   |
| ----- | ---------------- | ----------------------------------------- |
| CNAME | my-container-app | reverse-proxy-nginx-dnw.azurewebsites.net |

Name here should be the name of the Azure Container App and content the url of the nginx Azure Webapp.

# Issues

The downside of letting the deployment script create the Resource Group (RG) if it does not already exist is that the Service Principal (SP) needs more rights. If we create the RG manually first we can limit the scope when creating the SP like so:

```
az ad sp create-for-rbac \
  --name $SERVICE_PRINCIPAL_NAME \
  --role Contributor \
  --scopes /subscriptions/$AKS_SUBSCRIPTION_ID/resourceGroups/$AKS_RESOURCE_GROUP \
  --sdk-auth
```

Another issue is that running customer-facing Azure Container Apps is tricky if we allow scaling down to 0. Scaling up to 1 takes at least 5 seconds or so

# Force HTTPS

There are two ways to force HTTPs. Both working the same way, but returning a 301 redirect response.

The easiest way is to only allow HTTPS for the reverse-proxy Azure Webapp. That can be done under Settings -> TLS/SSL settings setting HTTPS Only to "On".

The second option is to use Cloudflare. In the Cloudflare Portal choose the domain first. Then under SSL/TLS -> Edge Certificates turn "Automatic HTTPS Rewrites" on. Note that Cloudflare has to be configured to act as a proxy for each DNS entry where you want to enable this.

# Issues

Having a seperate bash script is preferable over adding the script directly in the github actions yml file. Some things don't seem to work correctly when putting the bash commands in the github actions step directly.

A lot of bash commands don't return proper exit codes when things fo wrong though. That means the pipeline will actually succeed even though not all steps were successful.

# More resources on Azure Container Apps

https://docs.microsoft.com/en-us/azure/container-apps/get-started?tabs=bash

https://www.youtube.com/watch?v=fmGHEJL81rU

https://github.com/Azure-Samples/container-apps-store-api-microservice

Azure Containers Apps (not Azure App Services)
DAPR (https://docs.microsoft.com/en-us/azure/container-apps/connect-apps?tabs=bash)

https://www.withouttheloop.com/articles/2017-07-23-nginx-letsencrypt-azure-web-app/

https://docs.microsoft.com/en-us/azure/app-service/app-service-web-tutorial-custom-domain?tabs=wildcard%2Cazurecli

https://github.com/Azure-Samples/container-apps-store-api-microservice
