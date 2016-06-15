# toolchain
TOOLCHAIN       = i686-pc-linux-gnu
TOOLCHAIN_URL   = http://downloads.sourceforge.net/project/dsgpl/DSM%206.0%20Tool%20Chains/Intel%20x86%20Linux%203.2.40%20%28Evansport%29/evansport-gcc493_glibc220_linaro_i686-GPL.txz
TOOLCHAIN_PATH  = $(shell pwd)/toolchain/$(TOOLCHAIN)

# for staging install
STAGING_PATH = $(shell pwd)/staging
INSTALL_PREFIX = /usr/local

# openssl
OPENSSL         = openssl-1.0.2h
OPENSSL_TB      = $(OPENSSL).tar.gz
OPENSSL_URL     = https://www.openssl.org/source/$(OPENSSL_TB)
OPENSSL_SHA1    = df7f3977bbeda67306bc2a427257dd7375319d7d
OPENSSL_ARCH    = linux-generic32

# zlib (building openssl with zlib support)
ZLIB      = zlib-1.2.8
ZLIB_TB   = $(ZLIB).tar.gz
ZLIB_URL  = http://zlib.net/$(ZLIB_TB)

# TVHeadend
TVHEADEND         = tvheadend
TVHEADEND_GIT     = https://github.com/tvheadend/tvheadend.git

ENV = CC=${TOOLCHAIN_PATH}/bin/i686-pc-linux-gnu-cc
ENV += RANLIB=${TOOLCHAIN_PATH}/bin/i686-pc-linux-gnu-ranlib
ENV += AR=${TOOLCHAIN_PATH}/bin/i686-pc-linux-gnu-ar
ENV += CFLAGS="${CFLAGS} -I${STAGING_PATH}${INSTALL_PREFIX}/include"
ENV += PKG_CONFIG_LIBDIR=$(STAGING_PATH)$(INSTALL_PREFIX)/lib/pkgconfig
ENV += PKG_CONFIG_SYSROOT_DIR=$(STAGING_PATH)
#ENV += CROSS_COMPILE=${TOOLCHAIN_PATH}/bin/i686-pc-linux-gnu- # used by hdhomerun makefile
RUN = env $(ENV)

all: tvheadend

$(TOOLCHAIN_PATH)/.bdownload:
	curl -L -o toolchain.txz $(TOOLCHAIN_URL) && mkdir toolchain && tar -xf toolchain.txz -C toolchain
	chmod -R 755 ${TOOLCHAIN_PATH}
	@echo Toolchain available in ${TOOLCHAIN_PATH}
	@touch $@

$(ZLIB)/.bdownload:
	curl -L -o ${ZLIB_TB} ${ZLIB_URL} && tar -xf $(ZLIB_TB)
	@touch $@

$(ZLIB)/.bbuild: $(ZLIB)/.bdownload $(TOOLCHAIN_PATH)/.bdownload
	cd $(ZLIB) && $(RUN) ./configure --prefix=${INSTALL_PREFIX} && $(MAKE) && $(MAKE) install prefix=$(STAGING_PATH)$(INSTALL_PREFIX)
	@echo Compiled and installed zlib into staging
	@touch $@

zlib: $(ZLIB)/.bbuild
	@echo zlib done.

$(OPENSSL)/.bdownload:
	curl -L -o $(OPENSSL_TB) $(OPENSSL_URL) && tar -xf $(OPENSSL_TB)
	@touch $@

$(OPENSSL)/.bbuild: $(OPENSSL)/.bdownload $(ZLIB)/.bbuild $(TOOLCHAIN_PATH)/.bdownload
	cd $(OPENSSL) && $(RUN) ./Configure --openssldir=${INSTALL_PREFIX} ${OPENSSL_ARCH} zlib-dynamic shared threads -I${STAGING_PATH}/include && $(MAKE) && $(MAKE) INSTALL_PREFIX=${STAGING_PATH} install_sw
	@touch $@

openssl: $(OPENSSL)/.bbuild
	@echo openssl done.

$(TVHEADEND)/.bclone:
	@echo Cloning TVHeadend git repo
	git clone https://github.com/tvheadend/tvheadend.git
	@touch $@
	
$(TVHEADEND)/.bbuild: openssl $(TOOLCHAIN_PATH)/.bdownload $(TVHEADEND)/.bclone
	@echo Updating TVHeadend git tree
	cd tvheadend && git pull
	@echo Building TVHeadend
	cd tvheadend && $(RUN) ./configure --disable-libav --disable-ffmpeg_static --disable-libx264 --disable-libvpx --disable-libtheora --disable-libvorbis --disable-libfdkaac ----disable-dbus_1 --prefix=$(INSTALL_PREFIX) && CROSS_COMPILE=${TOOLCHAIN_PATH}/bin/i686-pc-linux-gnu- $(MAKE) && $(MAKE) install DESTDIR=$(STAGING_PATH)

tvheadend: $(TVHEADEND)/.bbuild
	@echo tvheadend done.
