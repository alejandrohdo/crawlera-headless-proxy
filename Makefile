ROOT_DIR     := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
IMAGE_NAME   := crawlera-headless-proxy
APP_NAME     := $(IMAGE_NAME)
GOMETALINTER := gometalinter.v2

VENDOR_FILES := $(shell find "$(ROOT_DIR)/vendor" 2>/dev/null || echo -n "vendor")
CC_BINARIES  := $(shell bash -c "echo -n $(APP_NAME)-{linux,windows,darwin,freebsd,openbsd}-{386,amd64} $(APP_NAME)-linux-{arm,arm64}")
APP_DEPS     := version.go proxy/certs.go $(VENDOR_FILES)

# -----------------------------------------------------------------------------

$(APP_NAME): $(APP_DEPS)
	@go build -o "$(APP_NAME)" -ldflags="-s -w"

$(APP_NAME)-%: GOOS=$(shell echo -n "$@" | sed 's?$(APP_NAME)-??' | cut -f1 -d-)
$(APP_NAME)-%: GOARCH=$(shell echo -n "$@" | sed 's?$(APP_NAME)-??' | cut -f2 -d-)
$(APP_NAME)-%: $(APP_DEPS) ccbuilds
	@env "GOOS=$(GOOS)" "GOARCH=$(GOARCH)" \
		go build \
		-o "./ccbuilds/$(APP_NAME)-$(GOOS)-$(GOARCH)" \
		-ldflags="-s -w"

ccbuilds:
	@rm -rf ./ccbuilds && mkdir -p ./ccbuilds

version.go:
	@go generate main.go

proxy/certs.go:
	@go generate proxy/proxy.go

vendor: Gopkg.lock Gopkg.toml install-cli
	@dep ensure

# -----------------------------------------------------------------------------

.PHONY: all
all: $(APP_NAME)

.PHONY: crosscompile
crosscompile: $(CC_BINARIES)

.PHONY: crosscompile-dir
crosscompile-dir:
	@rm -rf "$(CC_DIR)" && mkdir -p "$(CC_DIR)"

.PHONY: test
test: vendor install-cli
	@go test -v ./...

.PHONY: lint
lint: vendor install-cli
	@$(GOMETALINTER) --deadline=2m ./...

.PHONY: clean
clean:
	@git clean -xfd && \
		git reset --hard >/dev/null && \
		git submodule foreach --recursive sh -c 'git clean -xfd && git reset --hard' >/dev/null

.PHONY: docker
docker:
	@docker build --pull -t "$(IMAGE_NAME)" "$(ROOT_DIR)"

.PHONY: install-cli
install-cli: install-dep install-lint

.PHONY: install-dep
install-dep:
	@go get github.com/golang/dep/cmd/dep

.PHONY: install-lint
install-lint:
	@go get gopkg.in/alecthomas/gometalinter.v2 && \
		$(GOMETALINTER) --install >/dev/null