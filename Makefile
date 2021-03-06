#
# Copyright (C) Original Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

SHELL := /bin/bash
NAME := gcs-copy
GO := $(shell command -v vgo || (go get -u golang.org/x/vgo > /dev/null && command -v vgo))
VERSION := $(shell ./scripts/get-version-number-from-latest-repo-tag.sh)
ROOT_PACKAGE := github.com/jenkins-x/gcs-copy
GO_VERSION := $(shell $(GO) version | sed -e 's/^[^0-9.]*\([0-9.]*\).*/\1/')
PACKAGE_DIRS := $(shell $(GO) list ./... | grep -v /vendor/)
PKGS := $(shell go list ./... | grep -v /vendor | grep -v generated)

REV        := $(shell git rev-parse --short HEAD 2> /dev/null  || echo 'unknown')
BRANCH     := $(shell git rev-parse --abbrev-ref HEAD 2> /dev/null  || echo 'unknown')
BUILD_DATE := $(shell date +%Y%m%d-%H:%M:%S)
BUILD_USER := $(shell whoami)

BUILDFLAGS := -ldflags \
  " -X $(ROOT_PACKAGE)/pkg/version.Version=$(VERSION)\
		-X $(ROOT_PACKAGE)/pkg/version.Revision='$(REV)'\
		-X $(ROOT_PACKAGE)/pkg/version.Branch='$(BRANCH)'\
		-X $(ROOT_PACKAGE)/pkg/version.BuildUser='$(BUILD_USER)'\
		-X $(ROOT_PACKAGE)/pkg/version.BuildDate='$(BUILD_DATE)'\
		-X $(ROOT_PACKAGE)/pkg/version.GoVersion='$(GO_VERSION)'"
CGO_ENABLED = 0

all: build

check: fmt build test

version-check:
ifndef VERSION
$(error VERSION is not set. You may have uncommitted changes. Please commit and try again)
endif

test: 
	CGO_ENABLED=$(CGO_ENABLED) $(GO) test $(PACKAGE_DIRS) -test.v

install:
	GOBIN=${GOPATH}/bin $(GO) install $(BUILDFLAGS) main.go

fmt:
	@FORMATTED=`$(GO) fmt $(PACKAGE_DIRS)`
	@([[ ! -z "$(FORMATTED)" ]] && printf "Fixed unformatted files:\n$(FORMATTED)") || true

build: osx arm win linux

osx: version-check
	CGO_ENABLED=$(CGO_ENABLED) $(GO) build $(BUILDFLAGS) -o build/osx/$(NAME) main.go

arm: version-check
	CGO_ENABLED=$(CGO_ENABLED) GOOS=linux GOARCH=arm $(GO) build $(BUILDFLAGS) -o build/arm/$(NAME) main.go

win: version-check
	CGO_ENABLED=$(CGO_ENABLED) GOOS=windows GOARCH=amd64 $(GO) build $(BUILDFLAGS) -o build/windows/$(NAME).exe main.go

linux: version-check
	CGO_ENABLED=$(CGO_ENABLED) GOOS=linux GOARCH=amd64 $(GO) build $(BUILDFLAGS) -o build/linux/gcs-copy main.go

docker-build: version-check linux
	docker build --no-cache -t $(DOCKER_HUB_USER)/gcs-copy:$(VERSION) .
	docker tag $(DOCKER_HUB_USER)/gcs-copy:$(VERSION) $(DOCKER_HUB_USER)/gcs-copy:latest

docker-push: docker-build
	docker push $(DOCKER_HUB_USER)/gcs-copy:$(VERSION) 
	docker push $(DOCKER_HUB_USER)/gcs-copy:latest

clean:
	rm -rf build release
