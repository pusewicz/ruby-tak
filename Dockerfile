ARG RUBY_VERSION=3.2.0
FROM ruby:$RUBY_VERSION

RUN bundle config --global frozen 1
RUN bundle config --global without "development test"

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["./exe/ruby_tak"]