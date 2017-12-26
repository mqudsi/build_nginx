NGXV=nginx-$(VERSION)

all: version.txt
	+$(MAKE) upgrade VERSION=`cat version.txt`

version.txt! #force update checks, always
	curl https://nginx.org/en/CHANGES | grep "Changes with" | egrep -o "[0-9]+\.[0-9]+\.[0-9]+" | head -n1 > version.txt
	@test -s version.txt || (echo "Failed to properly parse CHANGELOG!" 1>&2 && false)

upgrade: $(NGXV)/objs/nginx

install:
	# no hard Makefile dependency on version.txt to atomically install whatever was built
	@test -s version.txt || (echo "Run `make` before installing!" 1>&2 && false)
	# recursive make to force re-evaluation of $(NGXV)
	+$(MAKE) _install VERSION=`cat version.txt`

_install:
	+$(MAKE) -C $(NGXV) install

$(NGXV).tar.gz:
	wget https://nginx.org/download/nginx-$(VERSION).tar.gz

$(NGXV): $(NGXV).tar.gz
	tar xzvf $(NGXV).tar.gz

$(NGXV)/objs/nginx: $(NGXV)/Makefile
	+$(MAKE) -C $(NGXV)

$(NGXV)/Makefile: $(NGXV) ngx_cache_purge ngx_brotli zlib
	rm $@
	cd $(NGXV) && ./configure --prefix=/usr/local/etc/nginx --conf-path=/usr/local/etc/nginx/nginx.conf --sbin-path=/usr/local/sbin/nginx --pid-path=/var/run/nginx.pid --error-log-path=/var/log/nginx/error.log --http-client-body-temp-path=/var/tmp/nginx/client_body_temp --http-fastcgi-temp-path=/var/tmp/nginx/fastcgi_temp --http-proxy-temp-path=/var/tmp/nginx/proxy_temp --http-scgi-temp-path=/var/tmp/nginx/scgi_temp --http-uwsgi-temp-path=/var/tmp/nginx/uwsgi_temp --http-log-path=/var/log/nginx/access.log --user=www-data --group=www-data --with-http_ssl_module --with-http_realip_module --with-http_stub_status_module --with-http_v2_module --with-http_sub_module --add-module=../ngx_cache_purge --with-http_image_filter_module --with-http_gunzip_module --with-http_gzip_static_module --with-file-aio --with-pcre --with-pcre-jit --with-threads --with-google_perftools_module --add-module=../ngx_brotli --with-cc-opt=" -Wno-error -Ofast -funroll-loops -march=native -ffast-math " --with-zlib=../cf-zlib/ --with-zlib-opt="-O3 -march=native"

zlib:
	git clone https://github.com/cloudflare/zlib $@
	# cloudflare zlib requires gmake
	cp ./_BSDmakefile $@/BSDmakefile

ngx_cache_purge:
	git clone https://github.com/FRiCKLE/ngx_cache_purge

ngx_brotli:
	git clone git@github.com:neosmart/ngx_brotli.git
	cd ngx_brotli; git submodule update --init;

update:
	cd ngx_brotli; git pull; git submodule update --init;
	cd cf-zlib; git pull; git submodule update --init;
	cd ngx_cache_purge; git pull; git submodule update --init;
