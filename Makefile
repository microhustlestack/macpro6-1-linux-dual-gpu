PREFIX ?= /usr/local
DESTDIR ?=

.PHONY: all install uninstall test

all:
	@printf 'Run make install, make test, or ./bin/macpro61-gpu help\n'

install:
	install -Dm755 bin/macpro61-gpu "$(DESTDIR)$(PREFIX)/bin/macpro61-gpu"
	install -Dm755 examples/dual-transcode.sh "$(DESTDIR)$(PREFIX)/share/macpro61-dual-gpu/examples/dual-transcode.sh"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/macpro61-gpu"
	rm -f "$(DESTDIR)$(PREFIX)/share/macpro61-dual-gpu/examples/dual-transcode.sh"

test:
	bash -n bin/macpro61-gpu examples/dual-transcode.sh tests/test.sh
	bash tests/test.sh
