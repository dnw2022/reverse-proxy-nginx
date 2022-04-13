# Intro

At the time of writing Azure Container Apps do not support custom domains (see: https://stackoverflow.com/questions/70474387/how-to-use-a-custom-domain-with-a-azure-container-app). AGW and FrontDoor can be used, but are expensive.

One (cheap) way to get around the current limitation of not being able to use custom domains is to use an Azure (Web) App Service that acts as a reverse-proxy. Azure App Services (including Azure Web App Services) do support custom domains. In this case we use a custom nginx container as the reverse proxy.

As mentioned in the documenation, in Azure App Services TLS termination happens at the network load balancers. That means all HTTPS requests reach the app as unencrypted HTTP requests. That's the reason the nginx default.conf.tpl template file configures nginx to listen on port 80 instead of 443.

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
SUBSCRIPTION_ID=f2485aef-25f1-418d-bb35-92098bbf3b08 \
RESOURCE_GROUP=rg-dnw \
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

# SSH access

az webapp config set \
 --resource-group $RESOURCE_GROUP \
 -n reverse-proxy-nginx-dnw \
 --remote-debugging-enabled=false

az webapp create-remote-connection \
 --subscription $SUBSCRIPTION_ID \
 --resource-group $RESOURCE_GROUP \
 -n reverse-proxy-nginx-dnw

# Generate a (wildcard) certificate for your custom domain

The renew-certs github actions workflow (./.github/workflows/renew-certs.yml) creates a new certificate for the confired domain (or renews it when it expires within the next 14 days). The example uses the dotnet-works.com domain. The 14 days is configurable in the renew_certs.sh bash script that is executed by the workflow.

The example uses Certbot with the Cloudflare plugin to issue certificates. Its highly recommended you use the Letsencrypt staging environment to issue certificates while you are testing. The production environment has strict rate limits. Set the CERT_STAGING environment variable to true to use the Letsencrypt staging environment. Just realize that staging certs have a very short validity. So you might get errors when running the azure-app-service-deploy workflow which uploads a new certificate to Azure. To force issueing a new certificate simply remove the CERT_PFX_BASE64 secret and run the renew-certs workflow manually.

The renew-certs workflow runs on a cron schedule (daily at 4 PM) and can be invoked manually from the github UI.

Check the renew-certs.yml file's ENV section for an explanation of the environment variables needed. Creating an organization and defining secrets at the organization level allows you to use the secrets in all (public) repos within the organization. Note that renew-certs.sh stores the certificate pfx file and thumbprint as organizational secrets.

# Configure the reverse-proxy nginx Azure Web App to use the custom domain

The azure-app-service-deploy workflow (./.github/workflows/azure-app-service-deploy.yml) does everything for you during deployment.

# Update Cloudflare DNS

Add a CNAME record for each subdomain you want to :

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

# Pricing comparison

At the time of writing - April 2022 - Azure Container Apps is in preview, so prices might change in the near future:

https://azure.microsoft.com/en-us/pricing/details/container-apps/

The monthly cost of a (mostly) idle Azure Container App that receives less than 2 million requests per month are:

```
vCPU (0.25): 0.000003 USD vCPU/second * 60 * 60 * 24 * 30 days * 0.25 vCPU =  1.94 USD/month
Memory (0.5Gb): 0.000003 USD Gb/second * 60 * 60 * 24 * 30 days * 0.5 Gb =    3.89 USD/month
Total:                                                                        5.92 USD/month
```

Additionally to use a custom domain you need an Azure Web App. We will look at the linux pricing. Windows is much more expensive:

https://azure.microsoft.com/en-us/pricing/details/app-service/linux/

The B1 instance seems to be the cheapest option (the shared plans are only meant for development and testing):

```
B1 (1 vCPU, 1.75GB Ram): 0.018 USD/hour * 24 * 30 days = 12.96 USD/month
```

It looks like the best way is to run all the sites that need to be always running as Azure Web Apps under the B1 linux plan. This includes the nginx reverse proxy that forwards request to Azure Container Apps. Sites/apps for which its ok to scale back to 0 can be run as Azure Container Apps. Especially for microservice apps Azure Container Apps provides tools like DAPR to simplify discovery and interconnectivity. It also allows scaling different components of the Azure Container App to scale independently.

# More resources on Azure Container Apps

https://docs.microsoft.com/en-us/azure/container-apps/get-started?tabs=bash

https://www.youtube.com/watch?v=fmGHEJL81rU

https://github.com/Azure-Samples/container-apps-store-api-microservice

Azure Containers Apps (not Azure App Services)
DAPR (https://docs.microsoft.com/en-us/azure/container-apps/connect-apps?tabs=bash)

https://www.withouttheloop.com/articles/2017-07-23-nginx-letsencrypt-azure-web-app/

https://docs.microsoft.com/en-us/azure/app-service/app-service-web-tutorial-custom-domain?tabs=wildcard%2Cazurecli

https://github.com/Azure-Samples/container-apps-store-api-microservice
