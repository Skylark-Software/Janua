# Janua guacd - Apache Guacamole guacd with FreeRDP 3 support
# Copyright 2025 Skylark Software LLC
# Licensed under Apache License 2.0

ARG GUACAMOLE_VERSION=1.6.0
ARG FREERDP_VERSION=3.10.3

# Build stage for FreeRDP 3
FROM debian:bookworm-slim AS freerdp-builder

ARG FREERDP_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    git \
    libssl-dev \
    libx11-dev \
    libxext-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxkbfile-dev \
    libxv-dev \
    libxi-dev \
    libxdamage-dev \
    libxrandr-dev \
    libxrender-dev \
    libxfixes-dev \
    libasound2-dev \
    libcups2-dev \
    libpulse-dev \
    libjpeg-dev \
    libgsm1-dev \
    libusb-1.0-0-dev \
    libudev-dev \
    libdbus-glib-1-dev \
    uuid-dev \
    libxml2-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libfaad-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libpng-dev \
    libavcodec-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libpkcs11-helper1-dev \
    libkrb5-dev \
    libcjson-dev \
    libsdl2-dev \
    libsdl2-ttf-dev \
    libfuse3-dev \
    libwebkit2gtk-4.0-dev \
    # PipeWire support for Wayland audio
    libpipewire-0.3-dev \
    ninja-build \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone --depth 1 --branch ${FREERDP_VERSION} https://github.com/FreeRDP/FreeRDP.git

WORKDIR /src/FreeRDP

RUN cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DWITH_SERVER=ON \
    -DWITH_CHANNELS=ON \
    -DWITH_CLIENT_CHANNELS=ON \
    -DWITH_SERVER_CHANNELS=ON \
    -DCHANNEL_RDPGFX=ON \
    -DCHANNEL_RDPSND=ON \
    -DWITH_PULSE=ON \
    -DWITH_ALSA=ON \
    -DWITH_PIPEWIRE=ON \
    -DWITH_JPEG=ON \
    -DWITH_OPENSSL=ON \
    -DWITH_GSM=ON \
    -DWITH_FAAD2=ON \
    -DWITH_FAAC=OFF \
    -DWITH_FFMPEG=ON \
    -DWITH_SWSCALE=ON \
    -DWITH_CAIRO=ON \
    -DWITH_PKCS11=ON \
    -DWITH_KRB5=ON \
    -DWITH_INTERNAL_MD4=ON \
    -DWITH_INTERNAL_MD5=ON \
    -DWITH_INTERNAL_RC4=ON \
    -DBUILD_SHARED_LIBS=ON \
    && cmake --build build -j$(nproc) \
    && DESTDIR=/freerdp-install cmake --install build

# Build stage for guacamole-server
FROM debian:bookworm-slim AS guacd-builder

ARG GUACAMOLE_VERSION

# Copy FreeRDP 3 from builder
COPY --from=freerdp-builder /freerdp-install/usr/local /usr/local

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    patch \
    pkg-config \
    autoconf \
    automake \
    libtool \
    libcairo2-dev \
    libgcrypt20-dev \
    libjpeg62-turbo-dev \
    libossp-uuid-dev \
    libpango1.0-dev \
    libpng-dev \
    libpulse-dev \
    libssl-dev \
    libtelnet-dev \
    libvncserver-dev \
    libvorbis-dev \
    libwebp-dev \
    libwebsockets-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    # FreeRDP build dependencies needed for header detection
    libx11-dev \
    libxext-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxkbfile-dev \
    libxv-dev \
    libxi-dev \
    libxdamage-dev \
    libxrandr-dev \
    libxrender-dev \
    libxfixes-dev \
    && rm -rf /var/lib/apt/lists/*

# Update library cache
RUN ldconfig

WORKDIR /src

RUN curl -fsSL "https://apache.org/dyn/closer.lua/guacamole/${GUACAMOLE_VERSION}/source/guacamole-server-${GUACAMOLE_VERSION}.tar.gz?action=download" -o guacamole-server.tar.gz \
    && tar -xzf guacamole-server.tar.gz

WORKDIR /src/guacamole-server-${GUACAMOLE_VERSION}

# Copy and apply patches for modern RDPSND protocol support
COPY patches/ /src/patches/
RUN for patch in /src/patches/*.patch; do \
        if [ -f "$patch" ]; then \
            echo "Applying patch: $patch"; \
            patch -p1 < "$patch"; \
        fi; \
    done

# Verify FreeRDP 3 is accessible
RUN pkg-config --modversion freerdp3 && \
    pkg-config --modversion freerdp-client3 && \
    pkg-config --modversion winpr3

# Configure with FreeRDP 3 support
RUN PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH \
    ./configure \
    --prefix=/usr/local \
    --with-rdp \
    --enable-allow-freerdp-snapshots

RUN make -j$(nproc) \
    && DESTDIR=/guacd-install make install

# Runtime image
FROM debian:bookworm-slim

LABEL maintainer="Skylark Software LLC"
LABEL description="Apache Guacamole guacd with FreeRDP 3 support"
LABEL version="1.0.0"
LABEL license="Apache-2.0"

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    ghostscript \
    libcairo2 \
    libgcrypt20 \
    libjpeg62-turbo \
    libossp-uuid16 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libpng16-16 \
    libpulse0 \
    libssl3 \
    libtelnet2 \
    libvncclient1 \
    libvorbis0a \
    libvorbisenc2 \
    libwebp7 \
    libwebpmux3 \
    libwebsockets17 \
    libavcodec59 \
    libavformat59 \
    libavutil57 \
    libswscale6 \
    fonts-dejavu \
    fonts-liberation \
    netcat-openbsd \
    # FreeRDP runtime deps
    libx11-6 \
    libxext6 \
    libxinerama1 \
    libxcursor1 \
    libxkbfile1 \
    libxv1 \
    libxi6 \
    libxdamage1 \
    libxrandr2 \
    libxrender1 \
    libxfixes3 \
    libasound2 \
    libcups2 \
    libgsm1 \
    libusb-1.0-0 \
    libcjson1 \
    libkrb5-3 \
    libfuse3-3 \
    libicu72 \
    # PipeWire runtime for Wayland audio support
    libpipewire-0.3-0 \
    pipewire \
    && rm -rf /var/lib/apt/lists/*

# Copy FreeRDP 3 libraries
COPY --from=freerdp-builder /freerdp-install/usr/local/lib /usr/local/lib
COPY --from=freerdp-builder /freerdp-install/usr/local/include /usr/local/include

# Copy guacd
COPY --from=guacd-builder /guacd-install/usr/local /usr/local

# Update library cache
RUN ldconfig

# Create guacd user
RUN useradd -r -s /sbin/nologin guacd

# Create directories
RUN mkdir -p /var/lib/guacd /var/log/guacd \
    && chown guacd:guacd /var/lib/guacd /var/log/guacd

USER guacd

EXPOSE 4822

CMD ["/usr/local/sbin/guacd", "-b", "0.0.0.0", "-L", "info", "-f"]
