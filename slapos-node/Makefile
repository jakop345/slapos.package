#!/usr/bin/make -f
# -*- makefile -*-

build: 
	cd slapos; make build

all: build

install: all
	cd slapos; make install
	mkdir -p $(DESTDIR)/usr/sbin/
	cp slapos-start $(DESTDIR)/usr/sbin/
	cp $(DESTDIR)/opt/slapos/bin/slapos $(DESTDIR)/usr/sbin/
clean:
#	cd slapos; make clean

# Début 23:39