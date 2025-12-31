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
LABEL org.opencontainers.image.source="https://github.com/Skylark-Software/Janua"

# Rename the WAR file so Tomcat deploys it at /janua instead of /guacamole
RUN mv /opt/guacamole/guacamole.war /opt/guacamole/janua.war
