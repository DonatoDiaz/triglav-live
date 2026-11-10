SHELL := /bin/bash
ROOT := $(shell pwd)

.PHONY: build iso clean shellcheck test-config install-workflow release

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

install-workflow:
	mkdir -p .github/workflows
	cp ci/build-iso.yml .github/workflows/build-iso.yml
	@echo "Файл установлен. Нужен gh scope workflow: gh auth refresh -h github.com -s workflow"

release:
	@v=$$(cat VERSION); iso=$$(ls out/*.iso | head -1); \
	gh release create "v$$v" "$$iso" "$$iso.sha256" \
	  --title "Triglav Live $$v" \
	  --notes "Triglav Live $$v — rescue-образ на базе Arch Linux."
