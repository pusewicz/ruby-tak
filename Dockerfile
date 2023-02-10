ARG RUBY_VERSION

################
# Stage: Builder
FROM ruby:$RUBY_VERSION-alpine as builder

RUN apk add --update --no-cache \
    build-base \
    git \
    tzdata

WORKDIR /app

COPY Gemfile* ./
RUN bundle config --global frozen 1 && \
    bundle config --global without "development test" && \
    bundle install && \
    rm -rf /usr/local/bundle/cache/*.gem && \
    find /usr/local/bundle/gems/ -name "*.c" -delete && \
    find /usr/local/bundle/gems/ -name "*.o" -delete

# Add the app
COPY . /app

##############
# Stage: Final
FROM ruby:$RUBY_VERSION-alpine
LABEL maintainer="piotr@layer22.com"

# Add user
RUN addgroup -g 1000 -S app \
 && adduser -u 1000 -S app -G app
USER app

# Copy app with gems from former build stage
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=app:app /app /app

WORKDIR /app

ENV RUBY_YJIT_ENABLE=1
ENV BUNDLE_WITHOUT="test:development"

EXPOSE 8089
VOLUME ["$HOME/.config/ruby_tak"]
ENTRYPOINT ["/app/entrypoint.sh"]
