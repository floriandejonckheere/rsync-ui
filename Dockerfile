FROM ruby:4.0.3-alpine3.23

LABEL maintainer="Florian Dejonckheere <florian@floriandejonckheere.be>"
LABEL org.opencontainers.image.source=https://github.com/floriandejonckheere/rsync-ui

ENV RUNTIME_DEPS postgresql gmp vips openssh rsync python3 py3-pip
ENV BUILD_DEPS build-base curl-dev git postgresql-dev yaml-dev cmake nodejs-current npm gmp-dev libffi-dev esbuild perl

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
RUN apk add --no-cache $BUILD_DEPS $RUNTIME_DEPS

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

# Enable corepack
RUN corepack enable

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
