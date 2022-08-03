FROM debian:bullseye-slim

LABEL maintainer="https://computestacks.com"
LABEL org.opencontainers.image.authors="https://computestacks.com"
LABEL org.opencontainers.image.source="https://git.cmptstks.com/cs-public/images/bastion"
LABEL org.opencontainers.image.url="https://git.cmptstks.com/cs-public/images/bastion"
LABEL org.opencontainers.image.title="SSH Bastion Image"

RUN set -ex; \
    \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y \
            zip \
            unzip \
            vim \
            nano \
            libxml2-dev \
            libbz2-dev \
            libmcrypt-dev \
            libcurl4-gnutls-dev \
            libc-client-dev \
            libkrb5-dev \
            libxslt-dev \
            lsb-release \
            zlib1g-dev \
            libicu-dev \
            locales \
            g++ \
            wget \
            rsync \
            tmux \
            git \
            curl \
            mariadb-client \
            php \
            php-curl \
            php-json \
            php-phar \
            php-dom \
            php-mysql \
            php-cli \
            php-pgsql \
            php-readline \
            openssl \
            ca-certificates \
            openssh-server \
            gnupg2 \
            make \
            iputils-ping \
            jq \
            mosh \
            ruby \
            rubygems \
            bundler \
            ftp \
    ; \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    ; \
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
    ; \
    curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -; \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list; \
    curl -sL https://deb.nodesource.com/setup_16.x | bash -; \
    apt-get install -y nodejs yarn postgresql-client-13 \
    ; \
    gem install --no-document http oj timeout \
    ; \
    apt-get clean \
    && rm -rf /var/lib/apt/lists/*; \
    sed -i 's/GROUP=1000/GROUP=1000/' /etc/default/useradd \
    && mkdir -p /var/run/sshd \
    && rm -f /etc/ssh/ssh_host_*key*

# This is required for `mosh` to function. Currently I've picked some common languages
# that I know are in use by ComputeStacks' users. 
#
# Possible alternatives:
#  1. have locale set by env variable and only load the one required by the user.
#  2. Generate all possibilities at installation
#     ```
#     cp /etc/locale.gen /etc/locale.gen.new
#     sed -r 's/# (.*).UTF-8 UTF-8/\1.UTF-8 UTF-8/g' /etc/locale.gen >> /etc/locale.gen.new
#     mv /etc/locale.gen.new /etc/locale.gen
#     ```
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# fi_FI.UTF-8 UTF-8/fi_FI.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# fr_CA.UTF-8 UTF-8/fr_CA.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# fr_CH.UTF-8 UTF-8/fr_CH.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# es_MX.UTF-8 UTF-8/es_MX.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# es_US.UTF-8 UTF-8/es_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# nl_NL.UTF-8 UTF-8/nl_NL.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# nl_BE.UTF-8 UTF-8/nl_BE.UTF-8 UTF-8/g' /etc/locale.gen \
    && sed -i 's/# fr_BE.UTF-8 UTF-8/fr_BE.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen

COPY fix_perms.sh /

RUN mkdir /etc/sftp.d \
    && mv /fix_perms.sh /etc/sftp.d/fix-permissions \
    && chmod +x /etc/sftp.d/fix-permissions \
    ; \
    wget https://getcomposer.org/composer.phar -O composer \
    && mv composer /usr/bin/composer \
    && chmod +x /usr/bin/composer \
    && composer self-update \
    ; \
    wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O wp \
    && mv wp /usr/bin/ \
    && chmod +x /usr/bin/wp

COPY sshd_config /etc/ssh/sshd_config
COPY ssh_config /etc/ssh/ssh_config
COPY vimrc /
COPY tmux /
COPY motd /etc/motd
COPY computestacks/init_bastion.rb /usr/local/bin/
COPY computestacks/load_ssh_keys.rb /usr/local/bin/

COPY entrypoint.sh /entrypoint
RUN chmod +x /entrypoint

# Will also listen on UDP if you activate mosh (initiated by the client).
EXPOSE 22/tcp

ENTRYPOINT ["/entrypoint"]
