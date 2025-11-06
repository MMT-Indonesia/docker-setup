FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG LARAVEL_REPO=""
ARG LARAVEL_REF="main"
ARG CI_A_REPO=""
ARG CI_A_REF="main"
ARG CI_B_REPO=""
ARG CI_B_REF="main"
ARG GIT_USERNAME="x-access-token"
ARG GIT_TOKEN=""

# Core packages + multi-PHP runtime (8.4 for Laravel, 7.4 for CI3)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    zip \
 && add-apt-repository -y ppa:ondrej/php \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    gosu \
    mariadb-server \
    nginx \
    openssh-server \
    php8.4 \
    php8.4-bcmath \
    php8.4-cli \
    php8.4-curl \
    php8.4-fpm \
    php8.4-intl \
    php8.4-mbstring \
    php8.4-mysql \
    php8.4-xml \
    php8.4-zip \
    php7.4 \
    php7.4-cli \
    php7.4-curl \
    php7.4-fpm \
   php7.4-intl \
    php7.4-mbstring \
    php7.4-mysql \
   php7.4-xml \
   php7.4-zip \
    supervisor \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Default CLI PHP to 8.4
RUN update-alternatives --set php /usr/bin/php8.4

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Runtime directories
RUN mkdir -p /run/php /run/mysqld /var/run/sshd /srv/www

# Application code (replace placeholders with real project sources before build)
COPY apps/ /srv/www/
RUN set -e; \
      AUTH_PREFIX=""; \
      if [ -n "$GIT_TOKEN" ]; then \
         AUTH_PREFIX="https://$GIT_USERNAME:$GIT_TOKEN@"; \
      fi; \
      if [ -n "$LARAVEL_REPO" ]; then \
         REPO_URL="$LARAVEL_REPO"; \
         if [ -n "$AUTH_PREFIX" ] && [ "${LARAVEL_REPO#https://}" != "$LARAVEL_REPO" ]; then \
            REPO_URL="${AUTH_PREFIX}${LARAVEL_REPO#https://}"; \
         fi; \
         rm -rf /srv/www/laravel-main \
         && git clone --depth 1 --branch "$LARAVEL_REF" "$REPO_URL" /srv/www/laravel-main \
         && rm -rf /srv/www/laravel-main/.git; \
      fi; \
      if [ -n "$CI_A_REPO" ]; then \
         REPO_URL="$CI_A_REPO"; \
         if [ -n "$AUTH_PREFIX" ] && [ "${CI_A_REPO#https://}" != "$CI_A_REPO" ]; then \
            REPO_URL="${AUTH_PREFIX}${CI_A_REPO#https://}"; \
         fi; \
         rm -rf /srv/www/ci-a \
         && git clone --depth 1 --branch "$CI_A_REF" "$REPO_URL" /srv/www/ci-a \
         && rm -rf /srv/www/ci-a/.git; \
      fi; \
      if [ -n "$CI_B_REPO" ]; then \
         REPO_URL="$CI_B_REPO"; \
         if [ -n "$AUTH_PREFIX" ] && [ "${CI_B_REPO#https://}" != "$CI_B_REPO" ]; then \
            REPO_URL="${AUTH_PREFIX}${CI_B_REPO#https://}"; \
         fi; \
         rm -rf /srv/www/ci-b \
         && git clone --depth 1 --branch "$CI_B_REF" "$REPO_URL" /srv/www/ci-b \
         && rm -rf /srv/www/ci-b/.git; \
      fi; \
      rm -f /tmp/git_*; \
      unset GIT_TOKEN AUTH_PREFIX REPO_URL

# Nginx configuration
COPY config/nginx/conf.d/ /etc/nginx/conf.d/

# Supervisor configuration
COPY config/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# MySQL bootstrap scripts
COPY config/mysql/ /docker-entrypoint-initdb.d/

# SSH/SFTP user
RUN useradd -m -d /srv/www -s /usr/sbin/nologin devschool \
 && usermod -a -G www-data devschool \
 && echo 'devschool:ChangeMeNow!' | chpasswd \
 && chown root:root /srv \
 && chmod 755 /srv \
 && chown -R devschool:www-data /srv/www \
 && chmod -R 775 /srv/www \
 && sed -i 's@Subsystem\s\+sftp\s\+/usr/lib/openssh/sftp-server@Subsystem sftp internal-sftp@' /etc/ssh/sshd_config \
 && printf '\nMatch User devschool\n  ChrootDirectory /srv\n  ForceCommand internal-sftp\n  X11Forwarding no\n  AllowTcpForwarding no\n' >> /etc/ssh/sshd_config

# Entrypoint
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 443 22 3306
VOLUME ["/var/lib/mysql"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
