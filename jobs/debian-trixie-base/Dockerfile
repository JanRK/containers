ARG BASE_TAG=trixie-slim
FROM ghcr.io/janrk/debian-trixie-slim:${BASE_TAG}

# ca-certificates first over plain http, so the https rewrite below can verify TLS.
RUN set -eux; \
    apt-get update; \
    apt-get install --yes --no-install-recommends ca-certificates; \
    find /etc/apt -type f \( -name '*.list' -o -name '*.sources' \) -exec sed -i \
        -e 's|https\?://ftp.acc.umu.se|https://deb.debian.org|g' \
        -e 's|https\?://ftp.dk.debian.org|https://deb.debian.org|g' \
        -e 's|https\?://ftp.debian.org|https://deb.debian.org|g' \
        -e 's|http://deb.debian.org|https://deb.debian.org|g' \
        -e 's|http://storage.googleapis.com|https://storage.googleapis.com|g' \
        -e 's|http://packages.cloud.google.com|https://packages.cloud.google.com|g' \
        -e 's|http://apt.llvm.org|https://apt.llvm.org|g' \
        -e 's|http://repo.mysql.com|https://repo.mysql.com|g' \
        -e 's|http://apt.postgresql.org|https://apt.postgresql.org|g' \
        -e 's|https\?://raspbian.raspberrypi.org/raspbian/|https://mirrors.dotsrc.org/raspbian/raspbian/|g' \
        -e 's|http://archive.raspberrypi.org|https://archive.raspberrypi.org|g' \
        -e 's|http://apt.armbian.com|https://apt.armbian.com|g' \
        -e 's|http://archive.raspberrypi.com|https://archive.raspberrypi.com|g' \
        -e 's|http://security.debian.org/debian-security|https://deb.debian.org/debian-security|g' \
        -e 's|http://security.ubuntu.com/ubuntu|https://security.ubuntu.com/ubuntu|g' \
        -e 's|http://eu-stockholm-1-ad-1.clouds.archive.ubuntu.com/ubuntu|https://eu-stockholm-1-ad-1.clouds.archive.ubuntu.com/ubuntu|g' \
        {} +; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get update; \
    apt-get install --yes --no-install-recommends curl wget nano unzip 7zip dirmngr gnupg; \
    rm -rf /var/lib/apt/lists/*
