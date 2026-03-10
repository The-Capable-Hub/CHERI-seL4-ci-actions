# Common helper functions
set_target_from_arch() {
case "${INPUT_ARCH}" in
    RISCV64)
        TARGET="riscv64"
        BOARD="qemu_virt_riscv64"
        TARGET_IS_PURECAP=false
        ;;
    RISCV64_CHERI)
        TARGET="riscv64-purecap"
        BOARD="qemu_virt_riscv64"
        TARGET_IS_PURECAP=true
        ;;
    *)
        echo "INPUT_ARCH: ${INPUT_ARCH}: Unrecognised target" && exit 1
        ;;
esac
}
