# Cloudflare token

Create Cloudflare API token in their Management portal with these permissions:

| Token name   | Permissions                       | Resources           |
| ------------ | --------------------------------- | ------------------- |
| {token name} | Zone.Zone (Read), Zone.DNS (Edit) | Include (All zones) |

You will need this token when creating a certificate issued by LetsEncrypt using Certbot in the next step.

# Manual certificate creation (without cert-manager)

https://eff-certbot.readthedocs.io/en/stable/install.html

Note that its possible to use the manual (interactive) mode or automated one.

For the automated mode:

```
docker-compose build
source <(security find-generic-password -w -s 'cli_keys' -a '$(id -un)' | base64 --decode) (on mac)
source <(cat ~/.secrets/cli_keys.json) (on linux)
ID=$(docker-compose run -d --rm certbot)
docker exec $ID sh /src/cert_init.sh $CLOUDFLARE_TOKEN
docker exec -it $ID sh

certbot certonly \
  --non-interactive \
  --agree-tos \
  --preferred-challenges dns \
  --test-cert \
  --dns-cloudflare \
  --dns-cloudflare-credentials ./cloudflare.ini \
  -m jeroen_bijlsma@yahoo.com \
  -d testing.freelancedirekt.nl

# For wildcard domains escape *
#-d \*.your-domain.com

# to see details (such as issuer)
openssl x509 -in /etc/letsencrypt/live/testing.freelancedirekt.nl/fullchain.pem -text
```

The manual mode:

```
certbot certonly \
  --manual \
  --preferred-challenges dns \
  --debug-challenges \
  --test-cert \
  --dry-run \
  --dns-cloudflare \
  --dns-cloudflare-credentials ./cloudflare.ini \
  -m jeroen_bijlsma@yahoo.com \
  -d \*.your-domain.com

docker kill $ID
```
