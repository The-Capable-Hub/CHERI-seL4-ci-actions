#!/bin/bash

set -e
if [ -n "$DEBUG_ACTION" ]; then
    set -x
fi

# Include common helper functions
. ${GITHUB_ACTION_PATH}/../cheri-sel4microkittest/microkit_targets.sh

init() {
    cd ${SEL4_MICROKIT_DIR}

    set_target_from_arch
    echo "TARGET=${TARGET}"
    echo "BOARD=${BOARD}"
    echo "TARGET_IS_PURECAP=${TARGET_IS_PURECAP}"
    echo "MICROKIT_TARGET=${MICROKIT_TARGET}"
}

configure() {
    python3 -m venv pyenv
    ./pyenv/bin/pip install --upgrade pip setuptools wheel
    ./pyenv/bin/pip install -r requirements.txt

    set_microkit_compiler_flags
}

build() {
    ./pyenv/bin/python build_sdk.py --sel4 ${SEL4_KERNEL_DIR} --skip-docs --skip-tar ${additional_flags} ${additional_flags_sdk} --boards ${BOARD}
}

init
configure
build
