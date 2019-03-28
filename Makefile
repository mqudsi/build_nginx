NGXV=nginx-$(VERSION)

all: upgrade

version.txt!
	curl https://nginx.org/en/CHANGES | grep "Changes with" | egrep -o "[0-9]+\.[0-9]+\.[0-9]+" | head -n1 > version.txt
	@test -s version.txt || (echo "Failed to properly parse CHANGELOG!" 1>&2 && false)

.PHONY: upgrade
upgrade! .update
	@+$(MAKE) .upgrade VERSION=`cat version.txt`

.upgrade: $(NGXV)/objs/nginx

install:
	# no hard Makefile dependency on version.txt to atomically install whatever was built
	@test -s version.txt || (echo "Run `make` before installing!" 1>&2 && false)
	# recursive make to force re-evaluation of $(NGXV)
	+$(MAKE) _install VERSION=`cat version.txt`

MMDB = $(:!tar -tvf GeoLite2-Country.tar.gz | egrep -o '[^ ]+\.mmdb'!)
_install: $(NGXV)/Makefile
	+$(MAKE) -C $(NGXV) install
	mkdir -p /var/db/geoip2
	install $(MMDB) /var/db/geoip2

$(NGXV).tar.gz:
	wget https://nginx.org/download/nginx-$(VERSION).tar.gz

$(NGXV): $(NGXV).tar.gz
	tar xzvf $?
	touch $@

$(NGXV)/objs/nginx: $(NGXV)/Makefile
	+$(MAKE) -C $(NGXV)
	touch $@

$(NGXV)/Makefile: $(NGXV)
	cd $(NGXV); env CFLAGS="-I/usr/local/include" ./configure --prefix=/usr/local/etc/nginx --conf-path=/usr/local/etc/nginx/nginx.conf --sbin-path=/usr/local/sbin/nginx --pid-path=/var/run/nginx.pid --error-log-path=/var/log/nginx/error.log --http-client-body-temp-path=/var/tmp/nginx/client_body_temp --http-fastcgi-temp-path=/var/tmp/nginx/fastcgi_temp --http-proxy-temp-path=/var/tmp/nginx/proxy_temp --http-scgi-temp-path=/var/tmp/nginx/scgi_temp --http-uwsgi-temp-path=/var/tmp/nginx/uwsgi_temp --http-log-path=/var/log/nginx/access.log --user=www-data --group=www-data --with-http_ssl_module --with-http_realip_module --with-http_stub_status_module --with-http_v2_module --with-http_sub_module --add-module=../ngx_cache_purge --with-http_image_filter_module --with-http_gunzip_module --with-http_gzip_static_module --with-file-aio --with-pcre --with-pcre-jit --with-threads --with-google_perftools_module --add-module=../ngx_brotli --with-cc-opt=" -Wno-error -Ofast -funroll-loops -march=native -ffast-math " --with-zlib=../zlib/ --with-zlib-opt="-O3 -march=native" --add-module=../ngx_http_geoip2_module --with-ld-opt="-L/usr/local/lib" ; cd -
	touch $@

zlib:
	git clone https://github.com/cloudflare/zlib $@
	# cloudflare zlib requires gmake, so we force it
	cp ./_BSDmakefile ./$@/BSDmakefile
	# nginx calls `make distclean` in zlib before calling zlib's ./configure,
	# but cloudflare's zlib has no Makefile until configured
	zlib/configure
	touch $@

ngx_cache_purge:
	git clone https://github.com/FRiCKLE/ngx_cache_purge
	touch $@

ngx_brotli:
	git clone git@github.com:neosmart/ngx_brotli.git
	cd $@; git submodule update --init; cd -
	touch $@

ngx_http_geoip2_module:
	git clone https://github.com/leev/ngx_http_geoip2_module
	cd $@; git submodule update --init; cd -
	touch $@

GeoLite2-Country.tar.gz:
	rm -f $@
	wget https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz

$(MMDB): GeoLite2-Country.tar.gz
	tar -xvf $? $(MMDB)

.PHONY: update
update!
	cd ngx_brotli; git pull; git submodule update --init; cd -
	cd zlib; git pull; git submodule update --init; cd -
	cd ngx_cache_purge; git pull; git submodule update --init; cd -
	cd ngx_http_geoip2_module; git pull; git submodule update --init; cd -
	touch .update

.update: zlib ngx_cache_purge ngx_brotli ngx_http_geoip2_module GeoLite2-Country.tar.gz $(MMDB) version.txt
	+$(MAKE) update

restart:
	killall -9 nginx
	nginx

clean: version.txt
	+$(MAKE) _clean VERSION=`cat version.txt`

_clean:
	rm $(NGXV)/Makefile
	rm -rf $(NGXV)
	rm -rf nginx-*
	rm -rf *.tar.gz

.for url in https://neosmart.net/ https://neosmart.net/php.php https://neosmart.net/favicon.ico https://neosmart.net/blog/ https://neosmart.net/forums/ https://neosmart.net/EasyRE/ https://neosmart.net/EasyRE/Admin/HealthCheck https://neosmart.net/EasyBCD/ https://neosmart.net/status.php

TEST_TARGETS += test_$(url:hash)
test_$(url:hash):
	@echo Testing: "$(url)"
	@echo @test $(:!curl -s -o /dev/null -w "%{http_code}" "$(url)"!) -eq 200 || echo "Url did not respond with HTTP 200!"

.endfor

test: $(TEST_TARGETS)

