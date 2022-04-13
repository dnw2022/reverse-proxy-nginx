FROM nginx

# Copy the nginx config file
COPY default.conf /etc/nginx/conf.d/default.conf

# Install OpenSSH and set the password for root to "Docker!".
RUN mkdir -p /home/LogFiles /opt/startup \
     && echo "root:Docker!" | chpasswd \
     && echo "cd /home" >> /etc/bash.bashrc \
     && apt-get update \  
     && apt-get install --yes --no-install-recommends \
      openssh-server \
      vim \
      curl \
      wget \
      tcptraceroute \
      openrc \
      yarn \
      net-tools \
      dnsutils \
      tcpdump \
      iproute2

RUN mkdir -p /opt/startup
COPY init_container.sh /opt/startup/init_container.sh
RUN chmod -R +x /opt/startup

# Copy the sshd_config file to the /etc/ssh/ directory
RUN rm -f /etc/ssh/sshd_config
COPY sshd_config /etc/ssh/sshd_config
RUN mkdir -p /home/LogFiles \
     && echo "root:Docker!" | chpasswd \
     && echo "cd /home" >> /root/.bashrc 

RUN mkdir -p /var/run/sshd

# Open port 2222 for SSH access
ENV SSH_PORT 2222
EXPOSE 80 2222

ENV WEBSITE_ROLE_INSTANCE_ID localRoleInstance
ENV WEBSITE_INSTANCE_ID localInstance

# Start ssh deamon
ENTRYPOINT ["/opt/startup/init_container.sh"]