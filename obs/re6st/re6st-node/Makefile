#!/usr/bin/make -f
# -*- makefile -*-

build: 
	cd re6stnet; make build

all: build

install: all
	cd re6stnet; make install
	mkdir -p $(DESTDIR)/usr/bin/
	mkdir -p $(DESTDIR)/usr/sbin/
	cp $(DESTDIR)/opt/re6st/bin/re6st* $(DESTDIR)/usr/bin/
	mkdir -p $(DESTDIR)/var/lib/re6stnet
	mkdir -p $(DESTDIR)/var/log/re6stnet
	mkdir -p $(DESTDIR)/etc/re6stnet
	install -Dpm 0644 daemon/README.conf $(DESTDIR)/etc/re6stnet/README
	install -Dp daemon/network-manager $(DESTDIR)/etc/NetworkManager/dispatcher.d/50re6stnet
	
clean:
#	cd slapos; make clean
