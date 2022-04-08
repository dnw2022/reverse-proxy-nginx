#!/bin/bash

# Heavily borrowing from: https://www.atmosera.com/blog/using-github-actions-to-manage-certbot-lets-encrypt-certificates/

# If there is no certificate issue a new one 
expiring="Certificate will expire"

# If there is a certificate, check if it will expire soon
if [[ ! -z "$CERT_PFX_BASE64" ]]
then
  echo "$CERT_PFX_BASE64" | base64 --decode > cert.pfx

  openssl pkcs12 -in cert.pfx -out cert.pem -nodes -password pass:$CERT_PWD

  endInDays=14
  let endInSeconds=endInDays*24*60*60

  expiring=$(openssl x509 -in cert.pem -checkend $endInSeconds)

  echo $expiring

  rm ./cert.pem
fi

# Renew if certificate is expiring soon
if [[ $expiring != "Certificate will not expire" ]]
then
  echo "Renewal needed"

  sudo apt install -y certbot azure-cli openssl python3-certbot-dns-cloudflare

  echo "dns_cloudflare_api_key = $CLOUDFLARE_API_KEY" > ./cloudflare.ini
  echo "dns_cloudflare_email = $CERT_EMAIL" >> ./cloudflare.ini

  chmod -R 777 ./cloudflare.ini

  if [ $CERT_STAGING = true ]
  then
    echo "Issuing Staging Certificate"
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
  else
    echo "Issuing Production Certificate"
    sudo certbot certonly \
      --non-interactive \
      --agree-tos \
      --preferred-challenges dns \
      --dns-cloudflare \
      --dns-cloudflare-credentials ./cloudflare.ini \
      --config-dir . \
      --cert-path . \
      -m $CERT_EMAIL \
      -d $CERT_DOMAIN    
  fi

  # Certbot runs as root, so it creates all the files as root. This changes the permissions so that other utilities can read the file.
  echo "Set file permissions"
  sudo chmod -R 777 ./*

  echo "Create a PFX for Azure"
  DOMAIN_NAME=$(echo $CERT_DOMAIN | sed -e "s/\*.//g")
  openssl pkcs12 -inkey ./live/$DOMAIN_NAME/privkey.pem -in live/$DOMAIN_NAME/fullchain.pem -export -out cert.pfx -passout pass:$CERT_PWD

  sudo chmod 777 cert.pfx

  FINGER_PRINT=$(openssl pkcs12 -in ./cert.pfx -nodes -password pass:$CERT_PWD | openssl x509 -noout -fingerprint | sed -e "s/\SHA1 Fingerprint=//g" -e "s/\://g")
  
  # https://docs.github.com/en/enterprise-cloud@latest/actions/security-guides/encrypted-secrets
  cat cert.pfx | base64 > cert.base64

  echo "Store thumprint and pfx file as github secrets"
  gh secret set CERT_THUMBPRINT --org dnw2022 --visibility all --body "$FINGER_PRINT" 
  gh secret set CERT_PFX_BASE64 --org dnw2022 --visibility all < cert.base64

  echo "Cleanup Files"
  rm ./cloudflare.ini
  rm ./cert.pfx
  rm ./cert.base64

  # gh workflow run azure-app-service-deploy.yml --ref master
else
  echo "No renewal needed yet"
fi

exit 0