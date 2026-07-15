# Janua Web Frontend
# Copyright (C) 2025 Skylark Software LLC
#
# This project is licensed under the GNU General Public License v3.0 only (GPL-3.0-only).
#
# This image extends Apache Guacamole to rebrand the URL path from /guacamole to /janua.
# Apache Guacamole is licensed under the Apache License, Version 2.0.
# Copyright © The Apache Software Foundation.
#
# A copy of the Apache License, Version 2.0 is provided in the LICENSES directory
# or available at https://www.apache.org/licenses/LICENSE-2.0

FROM guacamole/guacamole:1.6.0

LABEL org.opencontainers.image.title="Janua Web"
LABEL org.opencontainers.image.description="Janua web frontend - Apache Guacamole with /janua URL path"
LABEL org.opencontainers.image.vendor="Skylark Software LLC"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"
LABEL org.opencontainers.image.version="1.2.0-beta.1"
LABEL org.opencontainers.image.source="https://github.com/Skylark-Software/Janua"

# Set the webapp context path to /janua instead of /guacamole
ENV WEBAPP_CONTEXT=janua

# Copy Janua favicon/logo files
COPY images/logo-64.png /tmp/janua-logo-64.png
COPY images/logo-144.png /tmp/janua-logo-144.png

# Replace Guacamole logos in the WAR file with Janua logos
USER root
RUN apt-get update && apt-get install -y --no-install-recommends zip && \
    cd /opt/guacamole/webapp && \
    mkdir -p /tmp/war-update/images && \
    cp /tmp/janua-logo-64.png /tmp/war-update/images/logo-64.png && \
    cp /tmp/janua-logo-144.png /tmp/war-update/images/logo-144.png && \
    cd /tmp/war-update && \
    zip -u /opt/guacamole/webapp/guacamole.war images/logo-64.png images/logo-144.png && \
    apt-get purge -y zip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* /tmp/*
USER guacamole
