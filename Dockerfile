FROM buildpack-deps:wheezy
MAINTAINER Chien Cong Nguyen (nguyen.chiencong@gmail.com)

RUN apt-get update && apt-get install -y curl procps && rm -rf /var/lib/apt/lists/*

ENV RUBY_MAJOR 2.2
ENV RUBY_VERSION 2.2.2

# some of ruby's build scripts are written in ruby
# we purge this later to make sure our final image uses what we just built
RUN apt-get update \
    && apt-get install -y bison ruby \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/src/ruby \
    && curl -SL "http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.bz2" \
        | tar -xjC /usr/src/ruby --strip-components=1 \
    && cd /usr/src/ruby \
    && autoconf \
    && ./configure --disable-install-doc \
    && make -j"$(nproc)" \
    && apt-get purge -y --auto-remove bison ruby \
    && make install \
    && rm -r /usr/src/ruby

# skip installing gem documentation
RUN echo 'gem: --no-rdoc --no-ri' >> /.gemrc

# install bundler
RUN gem install bundler

# Install nodejs
RUN curl -sL https://deb.nodesource.com/setup | bash - \
    && apt-get install -y nodejs && apt-get install -y build-essential

# Intall software-properties-common for add-apt-repository
RUN apt-get install -qq -y software-properties-common python-software-properties

# Install postgres client
RUN \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list &&\
    apt-get install -y wget ca-certificates &&\
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - &&\
    apt-get update && apt-get upgrade -y 
RUN apt-get install -y postgresql-9.3 postgresql-client-9.3 libpq-dev

# Install apps
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Install foreman
RUN gem install foreman

# Add Gemfile
ADD Gemfile /usr/src/app/
ADD Gemfile.lock /usr/src/app/
RUN bundle install --without development test -j4

# Set Rails ENV to production
ENV RAILS_ENV production
ENV RACK_ENV production

# Unicorn
RUN mkdir -p /usr/src/app/tmp/pids
RUN mkdir -p /usr/src/app/log
ADD config/unicorn.rb /usr/src/app/config/unicorn.rb

# Copy app files
ADD . /usr/src/app/
# Assets precompile
RUN bundle exec rake assets:precompile --trace 

# Add foreman config
ADD Procfile /usr/src/app/Procfile

# Expose port 80
EXPOSE 3000

# Expose log folder
VOLUME /usr/src/app/log

# Run foreman
CMD foreman start -f Procfile