# Compile all supported rsync versions side by side (see Job::RSYNC_VERSIONS)
FROM alpine:3.24 AS rsync

ARG RSYNC_VERSIONS="3.5.1 3.5.0 3.4.4 3.4.3 3.4.2 3.4.1 3.4.0"

RUN apk add --no-cache acl-dev attr-dev autoconf automake build-base libidn2-dev linux-headers lz4-dev openssl-dev perl popt-dev xxhash-dev zlib-dev zstd-dev

COPY docker/rsync/build.sh /usr/local/bin/build-rsync
RUN build-rsync $RSYNC_VERSIONS

FROM ruby:4.0.7-alpine3.24

LABEL maintainer="Florian Dejonckheere <florian@floriandejonckheere.be>"
LABEL org.opencontainers.image.source=https://github.com/floriandejonckheere/rsync-ui

ENV RUNTIME_DEPS acl-libs libcrypto3 libidn2 lz4-libs popt xxhash zlib zstd-libs gmp openssh postgresql py3-pip python3 rsync sshpass vips
ENV BUILD_DEPS build-base cmake curl-dev esbuild git gmp-dev libffi-dev nodejs-current npm perl postgresql-dev yaml-dev
ENV TEST_DEPS chromium

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8

ENV APP_HOME=/app
WORKDIR $APP_HOME

# Add user
ARG USER=docker
ARG UID=1000
ARG GID=1000

RUN addgroup -g $GID $USER
RUN adduser -D -u $UID -G $USER -h $APP_HOME $USER

# Install system dependencies
RUN apk add --no-cache $BUILD_DEPS $RUNTIME_DEPS $TEST_DEPS

# Copy compiled rsync versions
COPY --from=rsync /usr/lib/rsync /usr/lib/rsync

# Install Apprise (notification dispatcher)
ADD requirements.txt $APP_HOME
RUN python3 -m venv /opt/apprise-venv \
 && /opt/apprise-venv/bin/pip install --no-cache-dir -r requirements.txt \
 && /opt/apprise-venv/bin/apprise --version
ENV PATH="/opt/apprise-venv/bin:$PATH"

# Install Bundler
RUN gem update --system && gem install bundler

# Install Gem dependencies
ADD Gemfile $APP_HOME
ADD Gemfile.lock $APP_HOME

RUN bundle install --jobs 4 --retry 3 --verbose

# Force (re-)compilation of native extensions
RUN gem pristine --all

# Install and enable corepack (no longer bundled with Node.js since v25)
RUN npm install -g corepack && corepack enable

# Install NPM dependencies
ADD package.json /app
ADD yarn.lock /app

RUN yarn install

# Add application
ADD . $APP_HOME

RUN mkdir -p $APP_HOME/tmp/pids/

RUN chown -R $UID:$GID $APP_HOME/

# Change user
USER $USER

CMD ["foreman", "start"]
