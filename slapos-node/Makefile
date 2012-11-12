#!/usr/bin/make -f
# -*- makefile -*-

build: 
	cd slapos; make build

all: build

install: all
	cd slapos; make install
	mkdir -p $(DESTDIR)/usr/sbin/
	cp slapos-start $(DESTDIR)/usr/sbin/
	cp slapos-test $(DESTDIR)/usr/sbin/
	cp $(DESTDIR)/opt/slapos/bin/slapos $(DESTDIR)/usr/sbin/
	# Open VPN configuration
	mkdir -p $(DESTDIR)/etc/openvpn/
	cp -r template/openvpn/* $(DESTDIR)/etc/openvpn/
	mkdir -p $(DESTDIR)/etc/opt/slapos/
clean:
#	cd slapos; make clean
