# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT= \
    RAILS_LOG_TO_STDOUT=true

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential curl git libpq-dev postgresql-client && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

FROM base AS development
COPY . .
RUN chmod +x bin/*
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]

FROM base AS production
ENV RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=true
COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile && \
    rm -rf tmp/cache
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
