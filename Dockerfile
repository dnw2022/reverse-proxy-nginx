FROM nginx
COPY default.conf /etc/nginx/conf.d/default.conf
COPY dnw.crt /etc/ssl/ssl-bundle.crt
COPY dnw.key /etc/ssl/dnw.key