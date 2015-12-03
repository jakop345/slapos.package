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
	cp $(DESTDIR)/opt/slapos/bin/slapos $(DESTDIR)/usr/bin/
	mkdir -p $(DESTDIR)/etc/opt/slapos/
	mkdir -p $(DESTDIR)/etc/firewalld/
	cp -R $(DESTDIR)/opt/slapos/parts/firewalld/etc/firewalld/* $(DESTDIR)/etc/firewalld/
	mkdir -p $(DESTDIR)/opt/slapos/parts/dbus/var/run/dbus
clean:
#	cd slapos; make clean
