
MAKEFLAGS += -j2

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: submod
submod: ## if you forgot to "git clone --recursive", this fetches submodules
	git submodule update --init

.PHONY: server
server: hugosvr openbrowser ## run the dev server and start browser

.PHONY: hugosvr
hugosvr:
	hugo server

.PHONY: openbrowser
openbrowser:
	xdg-open http://localhost:1313/