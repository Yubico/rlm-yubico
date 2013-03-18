# Copyright (c) 2009-2013 Yubico AB
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above
#     copyright notice, this list of conditions and the following
#     disclaimer in the documentation and/or other materials provided
#     with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

VERSION = 0.5.2
PACKAGE = rlm_yubico
CODE = Makefile NEWS COPYING rlm_yubico.pl ykrlm-config.cfg \
       YKmap.pm ykmapping dictionary
TMPDIR = /tmp/tmp.rlm-yubico

all:
	@echo "Try 'make install' or 'make symlink'."
	@echo "Info: https://github.com/Yubico/rlm-yubico/"
	@exit 1

# Installation rules.

etcprefix = /etc/yubico/rlm
usrprefix = /usr/share/rlm_yubico
radgroup = freerad

install:
	install -D --mode 644 rlm_yubico.pl $(DESTDIR)$(usrprefix)/rlm_yubico.pl
	install -D --mode 644 YKmap.pm $(DESTDIR)$(usrprefix)/YKmap.pm
	install -D --mode 644 dictionary $(DESTDIR)$(usrprefix)/dictionary
	install -D --backup --group $(radgroup) --mode 640 ykrlm-config.cfg $(DESTDIR)$(etcprefix)/ykrlm-config.cfg
	install -D --backup --group $(radgroup) --mode 660 ykmapping $(DESTDIR)$(etcprefix)/ykmapping

$(PACKAGE)-$(VERSION).tar.gz: $(FILES)
	mkdir $(PACKAGE)-$(VERSION)
	cp $(CODE) $(PACKAGE)-$(VERSION)/
	git2cl > $(PACKAGE)-$(VERSION)/ChangeLog
	tar cfz $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION)
	rm -rf $(PACKAGE)-$(VERSION)

dist: $(PACKAGE)-$(VERSION).tar.gz

release: dist
	@if test -z "$(KEYID)"; then \
		echo "Try this instead:"; \
		echo "  make release KEYID=[PGPKEYID]"; \
		echo "For example:"; \
		echo "  make release KEYID=2117364A"; \
		exit 1; \
		fi
	@head -1 NEWS | grep -q "Version $(VERSION) (released `date -I`)" || \
		(echo 'error: You need to update date/version in NEWS'; exit 1)
	gpg --detach-sign --default-key $(KEYID) $(PACKAGE)-$(VERSION).tar.gz
	gpg --verify $(PACKAGE)-$(VERSION).tar.gz.sig

	git tag -u $(KEYID) -m "$(PACKAGE)-$(VERSION)" $(PACKAGE)-$(VERSION)
	git push
	git push --tags
	mkdir -p $(TMPDIR)
	mv $(PACKAGE)-$(VERSION).tar.gz $(TMPDIR)
	mv $(PACKAGE)-$(VERSION).tar.gz.sig $(TMPDIR)

	git checkout gh-pages
	mv $(TMPDIR)/$(PACKAGE)-$(VERSION).tar.gz releases/
	mv $(TMPDIR)/$(PACKAGE)-$(VERSION).tar.gz.sig releases/
	git add releases/$(PACKAGE)-$(VERSION).tar.gz
	git add releases/$(PACKAGE)-$(VERSION).tar.gz.sig
	rmdir --ignore-fail-on-non-empty $(TMPDIR)

	x=$$(ls -1v releases/$(PACKAGE)-*.tar.gz | awk -F\- '{print $$2}' \
	  | sed 's/.tar.gz//' | paste -sd ',' - | sed 's/,/, /g' \
	  | sed 's/\([0-9.]\{1,\}\)/"\1"/g');sed -i -e "2s/\[.*\]/[$$x]/" \
	  releases.html
	git add releases.html
	git commit -m "Added tarball for release $(VERSION)"
	git push
	git checkout master
