.PHONY: build build-no-cache run

NAME=core
TARGET=release
TAG=latest

build:
	@podman build --pull=newer --ssh default --file Containerfile --tag localhost/$(NAME):$(TAG)
	@podman image tree localhost/$(NAME):$(TAG)

build-no-cache:
	@podman build --pull=newer --no-cache --ssh default --file Containerfile --tag localhost/$(NAME):$(TAG)
	@podman image tree localhost/$(NAME):$(TAG)

run:
	@podman run --rm -it -p 3000:3000 localhost/$(NAME):$(TAG) bash