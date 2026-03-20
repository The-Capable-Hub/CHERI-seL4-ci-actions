# QEMU args and test runner

# Set QEMU variable for the target
find_qemu_for_target() {
    set +e
    case "${TARGET}" in
        riscv64)
            if [ "${TARGET_IS_PURECAP}" = true ]; then
                QEMU="qemu-system-riscv64cheri"
            else
                QEMU="qemu-system-riscv64"
            fi
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

# (RISCV64) Find the opensbi firmware bin
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

# Set QEMU_ARCH_ARGS for RISCV64 purecap
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

# Set QEMU_ARCH_ARGS for the target
set_qemu_args_for_target() {
    case "${TARGET}" in
        riscv64)
            if [ "${TARGET_IS_PURECAP}" = true ]; then
                set_qemu_args_riscv64_purecap
            else
                echo "Error: ${TARGET}: TODO: implement `set_qemu_args_riscv64`" && exit 1
            fi
            ;;
        *)
            echo "Error: ${TARGET}: Unsupported target" && exit 1
            ;;
    esac
}

# Run the binary specified under `QEMU` variable, waiting for a timeout or until a match is found in stdout.
# also stores stdout and stderr logs to the specified files.
# usage:
#    run_qemu <"string to match"> <path/to/stdout.log> <path/to/stderr.log> <qemu_args(bash array)>
run_qemu() {
    local match="$1"
    local stdout_log="$2"
    local stderr_log="$3"
    local qemu_args="$4"

    local timeout="30s"

    local qemu_pid
    local grep_pid

    # FIFO for watching stdout of QEMU
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
