SHELL := /bin/bash
ROOT := $(shell pwd)

.PHONY: build iso clean shellcheck test-config

build iso:
	./build.sh

clean:
	rm -rf out .build

shellcheck:
	shellcheck -x profile/overlay/usr/local/bin/* profile/overlay/usr/local/lib/triglav/*.sh build.sh docker/entrypoint.sh

test-config:
	bash -n build.sh docker/entrypoint.sh
	for f in profile/overlay/usr/local/bin/* profile/overlay/usr/local/lib/triglav/*.sh; do bash -n "$$f" || exit 1; done
	@echo "syntax OK"
