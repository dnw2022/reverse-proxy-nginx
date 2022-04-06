#!/bin/bash

# Heavily borrowing from: https://www.atmosera.com/blog/using-github-actions-to-manage-certbot-lets-encrypt-certificates/

# If there is no certificate issue a new one 
expiring="Certificate will expire"

# If there is a certificate, check if it will expire soon
if [[ ! -z "$CERT_PFX_BASE64" ]]
then
  echo "$CERT_PFX_BASE64" | base64 --decode > $CERT_DOMAIN.pfx

  openssl pkcs12 -in $CERT_DOMAIN.pfx -out $CERT_DOMAIN.pem -nodes -password pass:$CERT_PWD

  endInDays=45
  let endInSeconds=endInDays*24*60*60

  expiring=$(openssl x509 -in $CERT_DOMAIN.pem -checkend $endInSeconds)
fi

# Renew if certificate is expiring soon
if [[ $expiring != "Certificate will not expire" ]]
then
  echo "Renewal needed"

  sudo apt install -y certbot azure-cli openssl python3-certbot-dns-cloudflare

  echo "dns_cloudflare_api_key = $CLOUDFLARE_API_KEY" > ./cloudflare.ini
  echo "dns_cloudflare_email = $CERT_EMAIL" >> ./cloudflare.ini

  chmod -R 777 ./cloudflare.ini

  sudo certbot certonly \
    --non-interactive \
    --agree-tos \
    --preferred-challenges dns \
    --staging \
    --test-cert \
    --dns-cloudflare \
    --dns-cloudflare-credentials ./cloudflare.ini \
    --config-dir . \
    --cert-path . \
    -m $CERT_EMAIL \
    -d $CERT_DOMAIN

  # Certbot runs as root, so it creates all the files as root. This changes the permissions so that other utilities can read the file.
  echo "Set file permissions"
  sudo chmod -R 777 ./*

  echo "Create a PFX for Azure"
  openssl pkcs12 -inkey ./live/$CERT_DOMAIN/privkey.pem -in live/$CERT_DOMAIN/fullchain.pem -export -out $CERT_DOMAIN.pfx -passout pass:$CERT_PWD

  sudo chmod 777 $CERT_DOMAIN.pfx

  FINGER_PRINT=$(openssl pkcs12 -in ./$CERT_DOMAIN.pfx -nodes -password pass:$CERT_PWD | openssl x509 -noout -fingerprint | sed -e "s/\SHA1 Fingerprint=//g" -e "s/\://g")
  
  # https://docs.github.com/en/enterprise-cloud@latest/actions/security-guides/encrypted-secrets
  cat $CERT_DOMAIN.pfx | base64 > $CERT_DOMAIN.base64

  echo "Store thumprint and pfx file as github secrets"
  gh secret set CERT_THUMBPRINT --body "$FINGER_PRINT"
  gh secret set CERT_PFX_BASE64 < $CERT_DOMAIN.base64

  echo "Cleanup Files"
  rm ./cloudflare.ini
  rm ./$CERT_DOMAIN.pfx
  rm ./$CERT_DOMAIN.pem
  rm ./$CERT_DOMAIN.base64

  # gh workflow run azure-app-service-deploy.yml --ref master
else
  echo "No renewal needed yet"
fi

exit 0