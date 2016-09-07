#!/usr/bin/make -f
# -*- makefile -*-

build: 
	cd slapos; make build

all: build

install: all
	cd slapos; make install
	mkdir -p $(DESTDIR)/usr/bin/
	mkdir -p $(DESTDIR)/usr/sbin/
	cp slapos-tweak $(DESTDIR)/usr/sbin/
	sed -i "s/\/opt\/slapos\/rebootstrap\/parts/\/opt\/slapos\/parts/g" $(DESTDIR)/opt/slapos/bin/*
	cp $(DESTDIR)/opt/slapos/bin/slapos $(DESTDIR)/usr/bin/
	mkdir -p $(DESTDIR)/etc/opt/slapos/
	mkdir -p $(DESTDIR)/etc/firewalld/
	rm -rf $(DESTDIR)/opt/slapos/rebootstrap/parts/openssl
	cp -R $(DESTDIR)/opt/slapos/parts/openssl $(DESTDIR)/opt/slapos/rebootstrap/parts/openssl
	cp -R $(DESTDIR)/opt/slapos/parts/firewalld/etc/firewalld/* $(DESTDIR)/etc/firewalld/
	mkdir -p $(DESTDIR)/opt/slapos/parts/dbus/var/run/dbus
clean:
#	cd slapos; make clean
