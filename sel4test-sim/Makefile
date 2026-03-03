# Copyright 2021, Proofcraft Pty Ltd
#
# SPDX-License-Identifier: BSD-2-Clause

# To build the RISCV64-CHERI sel4test-sim Docker image:
# $ make IMG=cheri-sel4-ci-riscv-sel4test-sim:latest BASE_IMG=capablehub/cheri-sel4-ci-riscv-base:latest

default: build

BASE_IMG=trustworthysystems/sel4:latest
IMG=sel4/sel4test-sim:latest

build:
	docker build -t $(IMG) -f Dockerfile --build-arg BASE_IMG=$(BASE_IMG) ..

push: build
	docker push $(IMG)

run: build
	docker run -e GITHUB_REPOSITORY -e GITHUB_REF \
	  -e GITHUB_WORKSPACE -e INPUT_ARCH -e INPUT_MARCH -e INPUT_MODE \
		-e INPUT_COMPILER -e INPUT_DEBUG $(IMG)

test: build
	docker run -ti --entrypoint bash -e GITHUB_REPOSITORY -e GITHUB_REF \
	  -e GITHUB_WORKSPACE -e INPUT_ARCH -e INPUT_MARCH -e INPUT_MODE \
		-e INPUT_COMPILER -e INPUT_DEBUG -v $(shell pwd):/mnt:z $(IMG)
