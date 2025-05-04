# 1. Base image with all build and test deps
FROM ubuntu:24.04

# 2. Install OS packages and Perl tooling
RUN apt-get update --yes && \
    apt-get install --yes \
      build-essential \
      wget \
      git \
      libipset-dev ipset \
      libpcre3-dev libssl-dev \
      perl cpanminus \
      libtest-nginx-perl && \
    cpanm --notest --local-lib=/usr/local/perl5 \
      Test::Nginx::Socket

ENV PERL5LIB=/usr/local/perl5/lib/perl5

# 3. Copy your module source and test suite in
WORKDIR /opt/ipset-module
COPY . .

# 4. Download and build NGINX
RUN git clone --branch stable https://github.com/nginx/nginx.git nginx && \
    cd nginx && \
    ./auto/configure \
      --with-debug \
      --with-http_realip_module \
      --add-module=/opt/ipset-module && \
    make --jobs=$(nproc)

# 5. Run the Test::Nginx suite
CMD [ "prove", "-l", "t/10-ipset.t" ]