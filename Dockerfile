FROM nginx

# Copy the nginx config file
COPY default.conf /etc/nginx/conf.d/default.conf

RUN chmod +x init_container.sh
COPY init_container.sh /tmp/init_container.sh

# Install OpenSSH and set the password for root to "Docker!". In this example, "apk add" is the install instruction for an Alpine Linux-based image.
RUN apt-get update
RUN apt-get install -y openssh-server \
     && echo "root:Docker!" | chpasswd 

RUN mkdir -p /home/LogFiles 
RUN mkdir -p /opt/startup
RUN mkdir -p /var/run/sshd

# Copy the sshd_config file to the /etc/ssh/ directory
RUN rm -f /etc/ssh/sshd_config
COPY sshd_config /etc/ssh/sshd_config

# Open port 2222 for SSH access
ENV PORT 8080
ENV SSH_PORT 2222
EXPOSE 80 2222

ENV WEBSITE_ROLE_INSTANCE_ID localRoleInstance
ENV WEBSITE_INSTANCE_ID localInstance

# Start ssh deamon
ENTRYPOINT ["/tmp/init_container.sh"]