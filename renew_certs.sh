#!/bin/bash

sudo apt install -y certbot azure-cli openssl python3-certbot-dns-cloudflare

echo "dns_cloudflare_api_key = $CLOUDFLARE_API_KEY" > ./cloudfare.ini
echo "dns_cloudflare_email = $CERT_EMAIL" >> ./cloudfare.ini

chmod -R 777 ./cloudfare.ini

sudo certbot certonly \
  --non-interactive \
  --agree-tos \
  --preferred-challenges dns \
  --staging \
  --test-cert \
  --dns-cloudflare \
  --dns-cloudflare-credentials ./cloudfare.ini \
  --config-dir . \
  --cert-path . \
  -m $CERT_EMAIL \
  -d $CERT_DOMAIN

# Certbot runs as root, so it creates all the files as root. This changes the permissions so that other utilities can read the file.
echo "Set file permissions"
sudo chmod -R 777 ./*

echo "Create a PFX for Azure"
openssl pkcs12 -inkey ./live/$CERT_DOMAIN/privkey.pem -in live/$CERT_DOMAIN/fullchain.pem -export -out $CERT_DOMAIN.pfx -passout pass:$WILDCARD_PFX_PWD

sudo chmod 777 $CERT_DOMAIN.pfx

exit 0