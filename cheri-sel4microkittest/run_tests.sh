#!/bin/bash

set -e
if [ -n "$DEBUG_ACTION" ]; then
    set -x
fi

# Include common helper functions
. ${GITHUB_ACTION_PATH}/../cheri-sel4microkittest/common_microkit_targets.sh

# Include QEMU runner and arg builder functions
. ${GITHUB_ACTION_PATH}/../cheri-sel4microkittest/common_qemu.sh

QEMU_BASE_ARGS=(
    -nographic
)

QEMU_OUTPUT_DIR="qemu_run_logs"

RESULTS_PASS=()
RESULTS_FAIL=()

run_example() {
    local example="$1"
    local match="$2"

    #local img_name="${example}-cheri-sel4-microkit-${MICROKIT_TARGET}-${BOARD}.img"
    local img_name="${example}-${BOARD}.img"
    local full_img_name="${SEL4_MICROKIT_DIR}/install/${img_name}"
    local timeout="30s"
    local log_prefix="${QEMU_OUTPUT_DIR}/${example}"
    local stdout_log="${log_prefix}.stdout"
    local stderr_log="${log_prefix}.stderr"

    echo "::group::Run example '${example}'"

    if [ ! -f "${full_img_name}" ]; then
        echo "Error: ${full_img_name}: Not found"
        exit 1
    fi

    local qemu_test_args="-kernel ${full_img_name}"

    local qemu_args="${QEMU_BASE_ARGS[@]} \
        ${QEMU_ARCH_ARGS[@]} \
        ${qemu_test_args} \
    "

    set +e

    run_qemu "${match}" "${stdout_log}" "${stderr_log}" "${qemu_args}"
    local result=$?

    set -e

    if [[ "${result}" -ne "0" ]]; then
        if [[ "${result}" -eq "124" ]]; then
            echo "${example}: FAILURE: exptected '${match}' (status code: ${result})" 2>&1
        else
            echo "${example}: FAILURE: QEMU exited abnormally (status code: ${result})" 1>&2
        fi
        echo "${example}: Command was: '${QEMU} ${qemu_args}'" 1>&2
        echo "${example}: stdout:" 1>&2
        cat "${stdout_log}" 1>&2
        echo "" 1>&2
        echo "${example}: stderr:" 1>&2
        cat "${stderr_log}" 1>&2
        echo "" 1>&2

        RESULTS_FAIL+=("${example}")
    else
        echo "${example}: PASS"

        RESULTS_PASS+=("${example}")
    fi

    echo "::endgroup"
}

run_examples() {
    run_example "hello"             "hello, world"
    run_example "hierarchy"         "hello, world"
    run_example "passive_server"    "running on clients scheduling context"
    run_example "rust"              "hello, world from Rust!"
}

handle_test_results() {
    echo "::group::Results"
    echo "${#RESULTS_PASS[@]} cases passed, ${#RESULTS_FAIL[@]} cases failed"

    local res=0
    if [ "${#RESULTS_FAIL[@]}" -ne "0" ]; then
        echo "FAILURE: Some test cases failed:"
        for i in "${RESULTS_FAIL[@]}"
        do
            echo "    FAILED: ${i}"
        done
        res=1
    else
        echo "PASS: All test cases passed"
    fi
    echo "::endgroup"
    exit "${res}"
}

init() {
    set_target_from_arch

    find_qemu_for_target
    set_qemu_args_for_target

    mkdir ${QEMU_OUTPUT_DIR}
}

init
run_examples
handle_test_results
