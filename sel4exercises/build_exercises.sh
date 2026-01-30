#!/bin/bash

set -e
if [ -n "$DEBUG_ACTION" ]; then
    set -x
fi

# Include common helper functions
. microkit_targets.sh

LLVM_PATH="$(readlink -f $(dirname $(which clang))/../)"

export CLANG="${LLVM_PATH}/bin/clang"

GEN_IMAGE=${SEL4_EXERCISES_DIR}/tools/gen_image
CCC=${SEL4_EXERCISES_DIR}/tools/ccc

INSTALL_DIR=${SEL4_EXERCISES_DIR}/install

find_microkit_sdk() {
    shopt -s nullglob
    local dirs=( "${SEL4_MICROKIT_DIR}/release"/*/ )
    shopt -u nullglob

    if (( ${#dirs[@]} != 1 )); then
        echo "Error: expected exactly 1 directory in ${SEL4_MICROKIT_DIR}, found ${#dirs[@]}" >&2
        return 1
    fi

    local microkit_release="${dirs[0]%/}"
    echo "Using Microkit release dir: ${microkit_release}"

    export MICROKIT_SDK="${microkit_release}"
}

package_microkit_image() {
    local sys_file="$1"
    local img_stem="$2"

    local out_img="${INSTALL_DIR}/${img_stem}"

    ${MICROKIT_BIN} "${sys_file}" --search-path "${INSTALL_DIR}" --config cheri --board "${BOARD}" --output "${out_img}"
}

build_single_elf() {
    local all_src_c="$1"
    local elf="$2"

    local src_c=($all_src_c)
    local flags=""
    local target="${TARGET}"
    if [ "${TARGET_IS_PURECAP}" = true ]; then
        flags="-cheri-bounds=subobject-safe ${flags}"
    fi
    if [ "${TARGET}" == "riscv64" ]; then
        flags="-G0 ${flags}"
        if [ "${TARGET_IS_PURECAP}" = true ]; then
            target="riscv64-purecap"
        fi
    fi
    ${CCC} ${target} ${flags} "${src_c[@]}" -o "${elf}"
}

build_mission() {
    local mission="$1"
    echo "::group::Build mission '${mission}'"

    local src_dir="${SEL4_EXERCISES_DIR}/src/missions/${mission}"
    local common_src_dir="${SEL4_EXERCISES_DIR}/src/common"
    local sys_file="${src_dir}/${mission}.system"

    local src_serial_server="${common_src_dir}/serial_server.c"

    local elf_app="${INSTALL_DIR}/${mission}.elf"
    local elf_serial="${INSTALL_DIR}/serial_server.elf"

    if [ "${mission}" == "buffer-overflow-control-flow" ]; then
        local src_app_c="${src_dir}/buffer-overflow.c"
        local src_btpalloc_c="${src_dir}/btpalloc.c"

        build_single_elf "${src_app_c} ${src_btpalloc_c}" "${elf_app}"
        build_single_elf "${src_serial_server}" "${elf_serial}"

        local img_name="${mission}-cheri-sel4-microkit-${TARGET}-${BOARD}.img"
        package_microkit_image "${sys_file}" "${img_name}"
    elif [ "${mission}" == "uninitialized-stack-frame-control-flow" ]; then
        local src_app_c="${src_dir}/stack-mission.c"

        build_single_elf "${src_app_c} ${src_btpalloc_c}" "${elf_app}"
        build_single_elf "${src_serial_server}" "${elf_serial}"

        local img_name="${mission}-cheri-sel4-microkit-${TARGET}-${BOARD}.img"
        package_microkit_image "${sys_file}" "${img_name}"
    else
        echo "Error: Unknown mission: ${mission}"
        echo "::endgroup"
        exit 1
    fi

    echo "::endgroup"
}

build_exercise() {
    local exercise="$1"
    echo "::group::Build exercise '${exercise}'"

    local src_dir="${SEL4_EXERCISES_DIR}/src/exercises/${exercise}"

    local src_c="${src_dir}/${exercise}.c"
    local sys_file="${src_dir}/${exercise}.system"

    local elf="${INSTALL_DIR}/${exercise}.elf"
    build_single_elf "${src_c}" "${elf}"
    local img_name="${exercise}-cheri-sel4-microkit-${TARGET}-${BOARD}.img"
    package_microkit_image "${sys_file}" "${img_name}"

    echo "::endgroup"
}


# build compile_and_run
build_exercise_compile_and_run() {
    local src_dir="${SEL4_EXERCISES_DIR}/src/exercises/compile-and-run"
    echo "::group::Build exercise 'compile-and-run'"

    local elf="${INSTALL_DIR}/print-pointer.elf"
    ${CCC} ${TARGET} ${src_dir}/print-pointer.c -o ${elf}
    (cd ${INSTALL_DIR} && ${GEN_IMAGE} -a ${TARGET} -o "${INSTALL_DIR}/print-pointer-cheri-sel4-microkit-${TARGET}-${BOARD}.img" ${elf})

    if [ "${TARGET_IS_PURECAP}" = true ]; then
        elf="${INSTALL_DIR}/print-capability.elf"
        ${CCC} ${TARGET} ${src_dir}/print-capability.c -o ${elf}
        (cd ${INSTALL_DIR} && ${GEN_IMAGE} -a ${TARGET} -o "${INSTALL_DIR}/print-capability-cheri-sel4-microkit-${TARGET}-${BOARD}.img" ${elf})
    fi

    echo "::endgroup"
}

init() {
    cd ${SEL4_EXERCISES_DIR}
    mkdir -p ${INSTALL_DIR}

    set_target_from_arch
    echo "TARGET=${TARGET}"
    echo "BOARD=${BOARD}"

    set_microkit_compiler_flags
    echo "TARGET_IS_PURECAP=${TARGET_IS_PURECAP}"

    find_microkit_sdk || exit 1

    echo "SEL4_MICROKIT_DIR=${SEL4_MICROKIT_DIR}"
    echo "MICROKIT_SDK=${MICROKIT_SDK}"

    MICROKIT_BIN="${MICROKIT_SDK}/bin/microkit"
}

build_exercises_and_missions() {
    build_exercise "buffer-overflow-stack"
    build_exercise "buffer-overflow-global"
    build_exercise "cheri-tags"
    build_exercise "control-flow-pointer"
    build_exercise "cheri-allocator"
    build_exercise "subobject-bounds"
    build_exercise "type-confusion"

    build_exercise_compile_and_run

    build_mission "buffer-overflow-control-flow"
    build_mission "uninitialized-stack-frame-control-flow"
}

init
build_exercises_and_missions
