FROM ghcr.io/linuxserver/picons-builder as piconsstage

FROM alpine:3.18 as buildstage

ARG ARGTABLE_VER="2.13"

RUN apk add --no-cache \
    bash \
    xz \
    alpine-release \
    bash \
    ca-certificates \
    coreutils \
    curl \
    jq \
    netcat-openbsd \
    procps-ng \
    shadow \
    tzdata

RUN groupmod -g 1000 users && \
    useradd -u 1000 -U -d /config -s /bin/false user && \
    usermod -G users user

COPY --from=piconsstage /picons.tar.bz2 /picons.tar.bz2

RUN apk add --no-cache \
    autoconf \
    automake \
    bsd-compat-headers \
    build-base \
    cmake \
    ffmpeg4-dev \
    file \
    findutils \
    gettext-dev \
    git \
    gnu-libiconv-dev \
    libdvbcsa-dev \
    libgcrypt-dev \
    libhdhomerun-dev \
    libtool \
    libva-dev \
    libvpx-dev \
    libxml2-dev \
    libxslt-dev \
    linux-headers \
    openssl-dev \
    opus-dev \
    patch \
    pcre2-dev \
    pkgconf \
    pngquant \
    python3 \
    sdl2-dev \
    uriparser-dev \
    x264-dev \
    x265-dev \
    zlib-dev

# Use gnu-iconv.h
RUN rm -rf /usr/include/iconv.h && \
    cp /usr/include/gnu-libiconv/iconv.h /usr/include/iconv.h

# Compile tvheadend
RUN mkdir -p /tmp/tvheadend && \
    git clone https://github.com/tvheadend/tvheadend.git /tmp/tvheadend && \
    cd /tmp/tvheadend && \
    git checkout master && \
    ./configure \
        `#Encoding` \
        --disable-ffmpeg_static \
        --disable-libfdkaac_static \
        --disable-libtheora_static \
        --disable-libopus_static \
        --disable-libvorbis_static \
        --disable-libvpx_static \
        --disable-libx264_static \
        --disable-libx265_static \
        --disable-libfdkaac \
        --enable-libopus \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        \
        `#Options` \
        --disable-avahi \
        --disable-dbus_1 \
        --disable-bintray_cache \
        --disable-execinfo \
        --disable-hdhomerun_static \
        --enable-libav \
        --enable-pngquant \
        --enable-trace \
        --enable-vaapi \
        --infodir=/usr/share/info \
        --localstatedir=/var \
        --mandir=/usr/share/man \
        --prefix=/usr \
        --python=python3 \
        --sysconfdir=/config && \
    make -j 2 && \
    make DESTDIR=/tmp/tvheadend-build install

# Compile argtable2
RUN ARGTABLE_VER1="${ARGTABLE_VER//./-}" && \
    mkdir -p /tmp/argtable && \
    curl -s -o \
        /tmp/argtable-src.tar.gz -L \
        "https://sourceforge.net/projects/argtable/files/argtable/argtable-${ARGTABLE_VER}/argtable${ARGTABLE_VER1}.tar.gz" && \
    tar xf /tmp/argtable-src.tar.gz -C /tmp/argtable --strip-components=1 && \
    cd /tmp/argtable && \
    ./configure --prefix=/usr && \
    make -j 2 && \
    make check && \
    make DESTDIR=/tmp/argtable-build install && \
    cp -pr /tmp/argtable-build/usr/* /usr/

# Compile comskip
RUN git clone https://github.com/erikkaashoek/Comskip /tmp/comskip && \
    cd /tmp/comskip && \
    ./autogen.sh && \
    ./configure \
        --bindir=/usr/bin \
        --sysconfdir=/config/comskip && \
    make -j 2 && \
    make DESTDIR=/tmp/comskip-build install

# Extract picons
RUN mkdir -p /picons && \
    tar xf /picons.tar.bz2 -C /picons

FROM alpine:3.18

RUN apk add --no-cache \
    bsd-compat-headers \
    ffmpeg \
    ffmpeg4-libavcodec \
    ffmpeg4-libavdevice \
    ffmpeg4-libavfilter \
    ffmpeg4-libavformat \
    ffmpeg4-libavutil \
    ffmpeg4-libpostproc \
    ffmpeg4-libswresample \
    ffmpeg4-libswscale \
    gnu-libiconv \
    libdvbcsa \
    libhdhomerun-libs \
    libva \
    libva-intel-driver \
    intel-media-driver \
    mesa \
    libvpx \
    libxml2 \
    libxslt \
    linux-headers \
    opus \
    pcre2 \
    perl \
    perl-datetime-format-strptime \
    perl-json \
    py3-requests \
    python3 \
    uriparser \
    x264 \
    x265 \
    xmltv \
    zlib

COPY --from=buildstage /tmp/argtable-build/usr/ /usr/
COPY --from=buildstage /tmp/comskip-build/usr/ /usr/
COPY --from=buildstage /tmp/tvheadend-build/usr/ /usr/
COPY --from=buildstage /picons /picons

EXPOSE 9981 9982
VOLUME /config

USER user
CMD tvheadend -C -c /config
