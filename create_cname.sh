#!/bin/bash

# Example
# bash ./create_cname.sh "dotnet-works.com" "my-container-app2" "reverse-proxy-nginx-dnw.azurewebsites.net"

# $1 => DOMAIN
# $2 => APP_CNAME
# $3 => REVERSE_PROXY_URL

DOMAIN="$1"
APP_NAME="$2"
REVERSE_PROXY_URL="$3"

APP_CNAME="$APP_NAME.$DOMAIN"

http() {
  local url=$1
  local method="${2:-GET}"
  local data="$3"

  BASE_URL="https://api.cloudflare.com/client/v4"

  if [[ -z $data ]]
  then
    echo $(curl \
      -H "X-Auth-Key: $CF_AUTH_KEY" \
      -H "X-Auth-Email: $CF_EMAIL" \
      -s \
      "$BASE_URL$url")
  else
    echo $(curl -X POST "$BASE_URL$url" \
      -H "X-Auth-Key: $CF_AUTH_KEY" \
      -H "X-Auth-Email: $CF_EMAIL" \
      -s \
      -d "$data")
  fi
}

ZONE_ID=$(http "/zones?name=$DOMAIN" | jq ".result[0].id" | tr -d '"')

if [ "$ZONE_ID" = null ]
then
  exit 0
fi

CNAME_ID=$(http "/zones/$ZONE_ID/dns_records?type=CNAME&name=$APP_CNAME" | jq ".result[0].id" | tr -d '"')
echo "CNAME_ID=$CNAME_ID"

if [ "$CNAME_ID" = null ]
then
  body='{"type":"CNAME", "name":"'$APP_CNAME'", "content":"'$REVERSE_PROXY_URL'"}'
  http "/zones/$ZONE_ID/dns_records?type=CNAME&name=$APP_CNAME" "POST" "$body"
  exit 0
fi

exit 0