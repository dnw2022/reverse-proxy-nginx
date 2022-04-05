#$1 -> CLOUDFLARE_TOKEN

# https://certbot-dns-cloudflare.readthedocs.io/en/stable/
cat <<EOF > cloudflare.ini
# Cloudflare API token used by Certbot
dns_cloudflare_api_token = $1
EOF

chmod 700 cloudfare.ini