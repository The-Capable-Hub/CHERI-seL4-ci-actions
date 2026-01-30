#!/bin/bash

set -e
if [ -n "$DEBUG_ACTION" ]; then
    set -x
fi

# Include common helper functions
. microkit_targets.sh

INSTALL_DIR=${SEL4_MICROKIT_DIR}/install

additional_flags=""
additional_flags_sdk=""
additional_flags_build=""
case "${INPUT_COMPILER}" in
    gcc)
        ;;
    llvm)
        additional_flags="--llvm ${additional_flags}"
        ;;
    *)
        echo "Unknown COMPILER '${INPUT_COMPILER}'"
        exit 1
        ;;
esac

init() {
    cd ${SEL4_MICROKIT_DIR}

    set_target_from_arch
    echo "TARGET=${TARGET}"
    echo "BOARD=${BOARD}"
}

configure() {
    mkdir -p ${INSTALL_DIR}

    python3 -m venv pyenv
    ./pyenv/bin/pip install --upgrade pip setuptools wheel
    ./pyenv/bin/pip install -r requirements.txt

    if [ "${TARGET_IS_PURECAP}" = true ]; then
        additional_flags_sdk="--configs cheri ${additional_flags_sdk}"
        additional_flags_build="--cheri --config cheri ${additional_flags_build}"
    fi
}

build() {
    ./pyenv/bin/python build_sdk.py --sel4 ${SEL4_KERNEL_DIR} --skip-docs --skip-tar ${additional_flags} ${additional_flags_sdk} --boards ${BOARD}
}

build_example() {
    prog="$1"

    ./pyenv/bin/python dev_build.py --board ${BOARD} --example ${prog} --rebuild ${additional_flags} ${additional_flags_build}
    mv ${SEL4_MICROKIT_DIR}/tmp_build/loader.img ${INSTALL_DIR}/${prog}-${BOARD}.img
}

build_examples() {
    build_example hello
    build_example hierarchy
    build_example passive_server
    build_example rust
}

install() {
    :
}

init
configure
build
#build_examples
install
