NGXV=nginx-$(VERSION)

all:
	rm version.txt
	+$(MAKE) version.txt
	+$(MAKE) upgrade VERSION=`cat version.txt`

version.txt:
	curl https://nginx.org/en/CHANGES | grep "Changes with" | egrep -o "[0-9]+\.[0-9]+\.[0-9]+" | head -n1 > version.txt

upgrade: $(NGXV)/Makefile
	+$(MAKE) -C $(NGXV)

install: version.txt
	+$(MAKE) _install VERSION=`cat version.txt`

_install:
	+$(MAKE) -C $(NGXV) install

$(NGXV).tar.gz:
	wget https://nginx.org/download/nginx-$(VERSION).tar.gz

$(NGXV): nginx-$(VERSION).tar.gz
	tar xzvf nginx-$(VERSION).tar.gz

$(NGXV)/Makefile: $(NGXV) cf-zlib ngx_cache_purge ngx_brotli
	cd nginx-$(VERSION) && ./configure --prefix=/usr/local/etc/nginx --conf-path=/usr/local/etc/nginx/nginx.conf --sbin-path=/usr/local/sbin/nginx --pid-path=/var/run/nginx.pid --error-log-path=/var/log/nginx/error.log --http-client-body-temp-path=/var/tmp/nginx/client_body_temp --http-fastcgi-temp-path=/var/tmp/nginx/fastcgi_temp --http-proxy-temp-path=/var/tmp/nginx/proxy_temp --http-scgi-temp-path=/var/tmp/nginx/scgi_temp --http-uwsgi-temp-path=/var/tmp/nginx/uwsgi_temp --http-log-path=/var/log/nginx/access.log --user=www-data --group=www-data --with-http_ssl_module --with-http_realip_module --with-http_stub_status_module --with-http_v2_module --with-http_sub_module --add-module=../ngx_cache_purge --with-http_image_filter_module --with-http_gunzip_module --with-http_gzip_static_module --with-file-aio --with-pcre --with-pcre-jit --with-threads --with-google_perftools_module --add-module=../ngx_brotli --with-cc-opt=" -Wno-error -Ofast -funroll-loops -march=native -ffast-math " --with-zlib=../cf-zlib/ --with-zlib-opt="-O3 -march=native"

cf-zlib:
	git clone https://github.com/cloudflare/zlib cf-zlib
	# cloudflare zlib requires gmake
	cp ./_BSDmakefile cf-zlib/BSDmakefile

ngx_cache_purge:
	git clone https://github.com/FRiCKLE/ngx_cache_purge

ngx_brotli:
	git clone git@github.com:neosmart/ngx_brotli.git
	cd ngx_brotli; git submodule update --init;

update: .PHONY
	cd ngx_brotli; git pull; git submodule update --init;
	cd cf-zlib; git pull; git submodule update --init;
	cd ngx_cache_purge; git pull; git submodule update --init;
