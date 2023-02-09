ARG RUBY_VERSION=3.2.1
FROM ruby:$RUBY_VERSION

WORKDIR /app

COPY Gemfile* ./
RUN bundle config --global frozen 1 && \
    bundle config --global without "development test" && \
    bundle install && \
    rm -rf /usr/local/bundle/cache/*.gem && \
    find /usr/local/bundle/gems/ -name "*.c" -delete && \
    find /usr/local/bundle/gems/ -name "*.o" -delete

COPY . ./

ENV RUBY_YJIT_ENABLE=1

EXPOSE 8089
VOLUME ["$HOME/.config/ruby_tak"]
ENTRYPOINT ["/app/entrypoint.sh"]
