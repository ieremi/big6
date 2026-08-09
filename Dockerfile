FROM ruby:3.4

RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /big6

RUN gem install rails

CMD ["bash"]
