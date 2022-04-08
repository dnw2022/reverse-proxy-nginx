echo "$CERT_PFX_BASE64" | base64 --decode > cert.pfx
cat cert.pfx | base64 > cert.base64

gh secret set CERT_THUMBPRINT --org dnw2022 --visibility all --body "$CERT_THUMBPRINT"
gh secret set CERT_PFX_BASE64 --org dnw2022 --visibility all < cert.base64

rm ./cert.pfx
rm ./cert.base64