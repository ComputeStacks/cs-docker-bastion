FROM debian:bullseye-slim

LABEL maintainer="https://computestacks.com"
LABEL org.opencontainers.image.authors="https://computestacks.com"
LABEL org.opencontainers.image.source="https://github.com/ComputeStacks/cs-docker-bastion"
LABEL org.opencontainers.image.url="https://github.com/ComputeStacks/cs-docker-bastion"
LABEL org.opencontainers.image.title="SSH Bastion Image"

RUN set -ex \
    ; \
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
            php-dev \
            php-curl \
            php-json \
            php-phar \
            php-dom \
            php-mysql \
            php-cli \
            php-pgsql \
            php-readline \
            php-igbinary \
            php-msgpack \
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
            libzstd-dev \
            liblzf-dev \
    ; \
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg \
        && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg \
        && echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list \
        && echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/postgresql.list \
    ; \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    ; \
    apt-get update \
        && apt-get install -y redis-tools nodejs postgresql-client-15 \
    ; \
    gem install --no-document http oj timeout \
    ; \
    corepack enable \
    ; \
    apt-get clean \
        && rm -rf /var/lib/apt/lists/* \
    ; \
    sed -i 's/GROUP=1000/GROUP=1000/' /etc/default/useradd \
        && mkdir -p /var/run/sshd \
        && rm -f /etc/ssh/ssh_host_*key* \
    ; \
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
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
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

COPY sshd_config /etc/ssh/sshd_config
COPY ssh_config /etc/ssh/ssh_config
COPY vimrc /
COPY tmux /
COPY motd /etc/motd
COPY computestacks/init_bastion.rb /usr/local/bin/
COPY computestacks/load_ssh_keys.rb /usr/local/bin/
COPY fix_perms.sh /
COPY wordpress/install_ocp.sh /usr/local/bin/install_ocp
COPY entrypoint.sh /entrypoint

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
        && chmod +x /usr/bin/wp \
    ; \
    cd /usr/src; \
    git clone https://github.com/phpredis/phpredis.git \
        && cd /usr/src/phpredis \
        && git checkout $(curl -fs -L https://api.github.com/repos/phpredis/phpredis/releases/latest | grep -i "tag_name" | awk -F '"' '{print $4}') \
        && phpize \
        && ./configure --enable-redis-igbinary --enable-redis-zstd --with-liblzf --enable-redis-msgpack \
        && make \
        && make install \
        && echo "extension=redis.so" > $(/usr/bin/php-config --ini-dir)/redis.ini \
        && rm -rf /usr/src/phpredis \
    ; \
    RELAY_FILE=$(mktemp) \
        && RELAY_VERSION=$(curl -fs -L https://builds.r2.relay.so/meta/latest | awk -F '"' '{print $1}') \
        # Switch to `x86-64%2Blibssl3.tar.gz` for debian bookworm.
        && wget -O $RELAY_FILE "https://builds.r2.relay.so/$RELAY_VERSION/relay-$RELAY_VERSION-php7.4-debian-x86-64.tar.gz" \
        && tar -xzf $RELAY_FILE -C /usr/src \
        && mv /usr/src/relay-* /usr/src/relay \
    ; \
    chmod +x /usr/local/bin/install_ocp \
        && chmod +x /entrypoint


# Will also listen on UDP if you activate mosh (initiated by the client).
EXPOSE 22/tcp

ENTRYPOINT ["/entrypoint"]
