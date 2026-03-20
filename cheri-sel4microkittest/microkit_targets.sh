# Common helper functions

additional_flags=""
additional_flags_sdk=""
additional_flags_build=""

set_microkit_compiler_flags() {
    case "${INPUT_COMPILER}" in
        gcc)
            echo "GCC is not supported yet"
            exit 1
            ;;
        llvm)
            additional_flags="--llvm ${additional_flags}"
            ;;
        *)
            echo "Unknown COMPILER '${INPUT_COMPILER}'"
            exit 1
            ;;
    esac

    if [ "${TARGET_IS_PURECAP}" = true ]; then
        additional_flags_sdk="--configs cheri ${additional_flags_sdk}"
        additional_flags_build="--cheri --config cheri ${additional_flags_build}"
    fi
}

set_target_from_arch() {
    case "${INPUT_ARCH}" in
        RISCV64)
            TARGET="riscv64"
            MICROKIT_TARGET="riscv64"
            BOARD="qemu_virt_riscv64"
            TARGET_IS_PURECAP=false
            for ext in ${INPUT_ARCH_EXT-}; do
                case "${ext}" in
                    RVY)
                        TARGET_IS_PURECAP=true
                        MICROKIT_TARGET="riscv64-purecap"
                        ;;
                    *)
                        echo "RISCV64: Unknown ARCH_EXT '${ext}'"
                        exit 1
                        ;;
                esac
            done
            ;;
        *)
            echo "INPUT_ARCH: ${INPUT_ARCH}: Unrecognised target" && exit 1
            ;;
    esac
}
