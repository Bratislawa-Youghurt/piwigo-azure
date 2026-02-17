FROM lscr.io/linuxserver/piwigo:latest

# 1. Install OpenSSH and set root password
RUN apk add --no-cache openssh \
  && ssh-keygen -A \
  && echo "root:Docker!" | chpasswd

# 2. Configure SSH for Azure (Port 2222)
COPY sshd_config /etc/ssh/

# 3. Bake in the SSL Cert for MySQL
COPY DigiCertGlobalRootG2.crt.pem /usr/local/share/ca-certificates/DigiCertGlobalRootG2.crt.pem
RUN update-ca-certificates

# 4. Copy custom services
# Only copy our specific additions to avoid overwriting base image files 
# (which might have CRLF issues from the local windows repo)
COPY root/custom-services.d/ /custom-services.d/
COPY root/custom-cont-init.d/ /custom-cont-init.d/

# 4b. Copy s6-rc service for DB config generation (runs after init-piwigo-config)
COPY root/etc/s6-overlay/s6-rc.d/init-piwigo-dbconfig/ /etc/s6-overlay/s6-rc.d/init-piwigo-dbconfig/
COPY root/etc/s6-overlay/s6-rc.d/init-config-end/dependencies.d/init-piwigo-dbconfig /etc/s6-overlay/s6-rc.d/init-config-end/dependencies.d/init-piwigo-dbconfig
COPY root/etc/s6-overlay/s6-rc.d/user/contents.d/init-piwigo-dbconfig /etc/s6-overlay/s6-rc.d/user/contents.d/init-piwigo-dbconfig

# 5. Copy PHP configuration overrides (mysqli SSL, upload limits)
COPY root/etc/php84/conf.d/piwigo.ini /etc/php84/conf.d/piwigo.ini

# 6. Fix permissions and line endings for scripts and configs
RUN chmod +x /custom-services.d/sshd \
  && chmod +x /custom-cont-init.d/99-configure-db \
  && chmod +x /etc/s6-overlay/s6-rc.d/init-piwigo-dbconfig/run \
  && sed -i 's/\r$//' /custom-services.d/sshd \
  && sed -i 's/\r$//' /custom-cont-init.d/99-configure-db \
  && sed -i 's/\r$//' /etc/s6-overlay/s6-rc.d/init-piwigo-dbconfig/run \
  && sed -i 's/\r$//' /etc/s6-overlay/s6-rc.d/init-piwigo-dbconfig/up \
  && sed -i 's/\r$//' /etc/s6-overlay/s6-rc.d/init-piwigo-dbconfig/type \
  && sed -i 's/\r$//' /etc/ssh/sshd_config \
  && sed -i 's/\r$//' /etc/s6-overlay/s6-rc.d/init-piwigo-config/run

# 7. Add chown/lsiown wrappers to bypass Azure Files permission errors
# LinuxServer images try to chown /config and /gallery on startup via both
# 'chown' and 'lsiown'. This fails on Azure Files (SMB).
# We wrap both to always succeed silently.
RUN rm -f /bin/chown \
  && printf '#!/bin/sh\nbusybox chown "$@" 2>/dev/null || true\n' > /bin/chown \
  && chmod +x /bin/chown \
  && if [ -f /usr/local/bin/lsiown ]; then \
  cp /usr/local/bin/lsiown /usr/local/bin/lsiown.real; \
  printf '#!/bin/sh\n/usr/local/bin/lsiown.real "$@" 2>/dev/null || true\n' > /usr/local/bin/lsiown; \
  chmod +x /usr/local/bin/lsiown; \
  fi

EXPOSE 2222 80
