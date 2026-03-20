#!/bin/bash

set -e
if [ -n "$DEBUG_ACTION" ]; then
    set -x
fi

# Include common helper functions
. ${GITHUB_ACTION_PATH}/../cheri-sel4microkittest/microkit_targets.sh

INSTALL_DIR=${SEL4_MICROKIT_DIR}/install

init() {
    cd ${SEL4_MICROKIT_DIR}

    set_target_from_arch

    set +e
    export MICROKIT_SDK="$(find_microkit_sdk_release)"
    if [ $? -ne 0 ]; then
        echo "Error: microkit SDK release not found!"
        exit 1
    fi
    set -e

    echo "TARGET=${TARGET}"
    echo "BOARD=${BOARD}"
    echo "TARGET_IS_PURECAP=${TARGET_IS_PURECAP}"
    echo "MICROKIT_TARGET=${MICROKIT_TARGET}"
    echo "MICROKIT_SDK=${MICROKIT_SDK}"
}

configure() {
    mkdir -p ${INSTALL_DIR}

    python3 -m venv pyenv
    ./pyenv/bin/pip install --upgrade pip setuptools wheel
    ./pyenv/bin/pip install -r requirements.txt

    set_microkit_compiler_flags

    export SEL4_SDK="${MICROKIT_SDK}/board/${BOARD}"
    if [ "${TARGET_IS_PURECAP}" = true ]; then
        SEL4_SDK="${SEL4_SDK}/cheri"
    fi
}

build_example() {
    local prog="$1"
    echo "::group::Build example '${prog}'"

    ./pyenv/bin/python dev_build.py --board ${BOARD} --example ${prog} --rebuild ${additional_flags} ${additional_flags_build}
    mv ${SEL4_MICROKIT_DIR}/tmp_build/loader.img ${INSTALL_DIR}/${prog}-${BOARD}.img

    echo "::endgroup"
}

build_make_args() {
    local make_args=""

    make_args="${make_args} LIBMICROKIT=${SEL4_SDK}/lib"

    if [ "${MICROKIT_TARGET}" = "riscv64-purecap" ]; then
        make_args="${make_args} TOOLCHAIN= CPU= CC=clang LD=ld.lld AS=clang "
    fi
    if [ "${TARGET_IS_PURECAP}" = true ]; then
        make_args="${make_args} LIBS=-lmicrokit_purecap"
    fi

    echo "MAKE_ARGS=${make_args}"
    export MAKE_ARGS="${make_args}"
}

build_test() {
    local test_name="$1"
    echo "::group::Build test '${test_name}'"
    cd ${SEL4_MICROKIT_DIR}/tests/${test_name}

    build_make_args
    make ${MAKE_ARGS}
    mv ${SEL4_MICROKIT_DIR}/tests/${test_name}/${test_name}.elf ${INSTALL_DIR}/test-${test_name}.elf

    echo "::endgroup"
}

build_tests() {
    if [ "${TARGET}" == "aarch64" ]; then
        build_test capfault
        build_test overlaping_pages
        build_test simplemrs
    else
        : # No tests for riscv64 yet
        #build_test capfault
        #build_test overlaping_pages
        #build_test simplemrs
    fi
}

build_examples() {
    build_example hello
    build_example hierarchy
    build_example passive_server
    build_example rust
}

init
configure
build_examples
build_tests
