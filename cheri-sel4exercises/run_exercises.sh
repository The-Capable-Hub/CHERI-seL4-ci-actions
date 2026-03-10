#!/bin/bash

set -e
if [ -n "$DEBUG_ACTION" ]; then
    set -x
fi

# Include common helper functions
. microkit_targets.sh

QEMU_BASE_ARGS=(
    -nographic
)

QEMU_OUTPUT_DIR="qemu_run_logs"

RESULTS_PASS=()
RESULTS_FAIL=()

find_qemu_for_target() {
    set +e
    case "${TARGET}" in
        riscv64-purecap)
            QEMU="qemu-system-riscv64cheri"
            ;;
        *)
            echo "Error: ${TARGET}: Unsupported target" && exit 1
            ;;
    esac
    local qemu_path
    qemu_path="$(which ${QEMU})"
    if [[ $? -ne "0" ]]; then
        echo "Error: executable '${QEMU}' not found in PATH"
        exit 1
    fi
    echo "QEMU is: ${qemu_path}"
    set -e
}

find_opensbi_riscv64_purecap() {
    if [ -z "${OPENSBI_FW_DIR}" ]; then
        echo "Error: OPENSBI_FW_DIR not set"
        exit 1
    fi
    bios_path="${OPENSBI_FW_DIR}/lp64/generic/firmware/fw_jump.bin"

    if [ ! -f "${bios_path}" ]; then
        echo "Error: OpenSBI BIOS not found: ${bios_path}"
        exit 1
    fi

    OPENSBI_RISCV64_PURECAP_BIOS="${bios_path}"
}

set_qemu_args_riscv64_purecap() {
    machine="virt"
    memory_size="2G"

    find_opensbi_riscv64_purecap

    QEMU_ARCH_ARGS=(
        -M ${machine}
        -cpu codasip-a730,cheri_levels=2
        -smp 1
        -bios ${OPENSBI_RISCV64_PURECAP_BIOS}
        -m ${memory_size}
    )
}

set_qemu_args_for_target() {
    case "${TARGET}" in
        riscv64-purecap)
            set_qemu_args_riscv64_purecap
            ;;
        *)
            echo "Error: ${TARGET}: Unsupported target" && exit 1
            ;;
    esac
}

run_qemu() {
    local match="$1"
    local stdout_log="$2"
    local stderr_log="$3"
    local qemu_args="$4"

    local timeout="30s"

    local qemu_pid
    local grep_pid

    # FIFO for watching stdout
    local fifo
    fifo=$(mktemp -u)
    mkfifo "$fifo"

    # Start grep watcher
    grep -q "$match" <"$fifo" &
    grep_pid=$!

    # Run QEMU
    timeout --foreground --signal=INT "$timeout" \
        "$QEMU" \
        ${qemu_args} \
        > >(tee "$stdout_log" >"$fifo") \
        2> >(tee "$stderr_log" >&2) &

    qemu_pid=$!

    # Wait for either grep or QEMU to exit
    wait -n "$grep_pid" "$qemu_pid"
    test_result=$?

    if kill -0 "$grep_pid" 2>/dev/null; then
        # QEMU exited first (timeout or crash)
        kill "$grep_pid" 2>/dev/null
    else
        # Pattern matched
        kill -INT "$qemu_pid" 2>/dev/null
    fi
    wait "$qemu_pid"
    rm -f "$fifo"

    return $test_result
}

run_exercise() {
    local exercise="$1"
    local match="$2"

    local img_name="${exercise}-cheri-sel4-microkit-${TARGET}-${BOARD}.img"
    local full_img_name="${SEL4_EXERCISES_DIR}/install/${img_name}"
    local timeout="30s"
    local log_prefix="${QEMU_OUTPUT_DIR}/${exercise}"
    local stdout_log="${log_prefix}.stdout"
    local stderr_log="${log_prefix}.stderr"

    echo "::group::Run exercise '${exercise}'"

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
            echo "${exercise}: FAILURE: exptected '${match}' (status code: ${result})" 2>&1
        else
            echo "${exercise}: FAILURE: QEMU exited abnormally (status code: ${result})" 1>&2
        fi
        echo "${exercise}: Command was: '${QEMU} ${qemu_args}'" 1>&2
        echo "${exercise}: stdout:" 1>&2
        cat "${stdout_log}" 1>&2
        echo "" 1>&2
        echo "${exercise}: stderr:" 1>&2
        cat "${stderr_log}" 1>&2
        echo "" 1>&2

        RESULTS_FAIL+=("${exercise}")
    else
        echo "${exercise}: PASS"

        RESULTS_PASS+=("${exercise}")
    fi

    echo "::endgroup"
}

run_exercise_compile_and_run() {
    local expected
    if [ "${TARGET_IS_PURECAP}" = true ]; then
        expected="size of pointer: 16"
    else
        expected="size of pointer: 8"
    fi
    run_exercise "print-pointer" "${expected}"

    if [ "${TARGET_IS_PURECAP}" = true ]; then
        run_exercise "print-capability"         "cap to cap length: 16"
    fi
}

run_mission() {
    local mission="$1"
    local match="$2"

    local img_name="${mission}-cheri-sel4-microkit-${TARGET}-${BOARD}.img"
    local full_img_name="${SEL4_EXERCISES_DIR}/install/${img_name}"
    local timeout="30s"
    local log_prefix="${QEMU_OUTPUT_DIR}/${mission}"
    local stdout_log="${log_prefix}.stdout"
    local stderr_log="${log_prefix}.stderr"

    echo "::group::Run mission '${mission}'"

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
            echo "${mission}: FAILURE: exptected '${match}' (status code: ${result})" 2>&1
        else
            echo "${mission}: FAILURE: QEMU exited abnormally (status code: ${result})" 1>&2
        fi
        echo "${mission}: Command was: '${QEMU} ${qemu_args}'" 1>&2
        echo "${mission}: stdout:" 1>&2
        cat "${stdout_log}" 1>&2
        echo "" 1>&2
        echo "${mission}: stderr:" 1>&2
        cat "${stderr_log}" 1>&2
        echo "" 1>&2

        RESULTS_FAIL+=("${mission}")
    else
        echo "${mission}: PASS"

        RESULTS_PASS+=("${mission}")
    fi

    echo "::endgroup"
}

run_exercises_and_missions() {
    run_exercise "buffer-overflow-stack"        "Bounds violation"
    run_exercise "buffer-overflow-global"       "Bounds violation"
    run_exercise "cheri-tags"                   "Tag violation"
    run_exercise "cheri-allocator"              "Bounds violation"
    run_exercise "control-flow-pointer"         "Bounds violation"
    run_exercise "subobject-bounds"             "Bounds violation"
    run_exercise "type-confusion"               "Tag violation"
    run_exercise_compile_and_run

    run_mission "buffer-overflow-control-flow"              "Returning alloc ="
    run_mission "uninitialized-stack-frame-control-flow"    "provide some cookies"
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
run_exercises_and_missions
handle_test_results
