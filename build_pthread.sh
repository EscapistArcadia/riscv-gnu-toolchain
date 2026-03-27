#!/usr/bin/env bash

set -eo pipefail

TARGET_PREFIX=$(realpath ~/riscv)

INTERACTIVE=1
CLEAN=0
BOOT_BOARD=0
BUILD_EXAMPLE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            TARGET_PREFIX=$(realpath "$2")
            shift 2
            ;;
        # --dest)
        #     DESTINATION=$(realpath "$2")
        #     shift 2
        #     ;;
        # --clean)
        #     CLEAN=1
        #     shift
        #     ;;
        --no-interactive)
            INTERACTIVE=0
            shift
            ;;
        --build-example)
            BUILD_EXAMPLE=1
            shift
            while [[ $# -gt 0 && "$1" != "--" ]]; do
                EXAMPLE+=("$1")
                shift
            done
            ;;
        --boot-board)
            BOOT_BOARD=1
            ESP_DIR=$(realpath "$2")
            ESP_CONFIG=$3
            shift 3
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

RISCV_GNU_TOOLCHAIN_ROOT=$(printenv RISCV_GNU_TOOLCHAIN_ROOT 2>/dev/null || true)
if [ -z "$RISCV_GNU_TOOLCHAIN_ROOT" ]; then
    RISCV_GNU_TOOLCHAIN_ROOT=$(pwd)
fi

RISCV_GNU_TOOLCHAIN_ROOT=$(realpath $RISCV_GNU_TOOLCHAIN_ROOT)
GLIBC_BUILD_DIR="$RISCV_GNU_TOOLCHAIN_ROOT/build-glibc-linux-rv64imafdc-lp64d"
CONFIGURE_SCRIPT="$RISCV_GNU_TOOLCHAIN_ROOT/riscv-glibc/configure"

PWD=$(pwd)

export PATH="$TARGET_PREFIX/bin:$PATH"

# mkdir -p "$GLIBC_BUILD_DIR"
# cd "$GLIBC_BUILD_DIR" \
#     &&  CC="$TARGET_BIN/riscv64-unknown-linux-gnu-gcc" \
#         CXX="$TARGET_BIN/riscv64-unknown-linux-gnu-g++" \
#         CFLAGS=" -mcmodel=medlow -g -O2 " \
#         CXXFLAGS=" -mcmodel=medlow -g -O2 " \
#         ASFLAGS=" -mcmodel=medlow " \
#         $CONFIGURE_SCRIPT \
#             --host=riscv64-unknown-linux-gnu \
#             --prefix="/usr" \
#             --disable-werror \
#             --enable-shared \
#             --enable-obsolete-rpc \
#             --with-headers="$RISCV_GNU_TOOLCHAIN_ROOT/linux-headers/include" \
#             --disable-multilib \
#             --enable-kernel=3.0.0 \
#             --libdir=/usr/lib libc_cv_slibdir=/lib libc_cv_rtlddir=/lib

# mkdir -p "$GLIBC_BUILD_DIR"
cd "$GLIBC_BUILD_DIR"

build_target() {
    local target="$1"

    make -C $RISCV_GNU_TOOLCHAIN_ROOT/riscv-glibc/$target subdir=$target ..=../ install_root=$TARGET_PREFIX/sysroot objdir="$GLIBC_BUILD_DIR" install-headers -j `nproc`
    make -C $RISCV_GNU_TOOLCHAIN_ROOT/riscv-glibc/$target subdir=$target ..=../ install_root=$TARGET_PREFIX/sysroot objdir="$GLIBC_BUILD_DIR" subdir_lib -j `nproc`
    make -C $RISCV_GNU_TOOLCHAIN_ROOT/riscv-glibc/$target subdir=$target ..=../ install_root=$TARGET_PREFIX/sysroot objdir="$GLIBC_BUILD_DIR" others -j `nproc`
    make -C $RISCV_GNU_TOOLCHAIN_ROOT/riscv-glibc/$target subdir=$target ..=../ install_root=$TARGET_PREFIX/sysroot objdir="$GLIBC_BUILD_DIR" subdir_install
}

# clean_target() {
#     local target="$1"

#     make -C $RISCV_GNU_TOOLCHAIN_ROOT/riscv-glibc/$target subdir=$target ..=../ install_root=$TARGET_PREFIX/sysroot objdir="$GLIBC_BUILD_DIR" clean
# }

# if [ $CLEAN -eq 1 ]; then
#     clean_target "nptl"
# fi

# build_target "malloc"
build_target "nptl"

cp "$GLIBC_BUILD_DIR"/nptl/libpthread.so ${ESP_DIR}/socs/${ESP_CONFIG}/soft-build/ariane/sysroot/lib/libpthread-2.26.so
echo "cp $GLIBC_BUILD_DIR/nptl/libpthread.so ${ESP_DIR}/socs/${ESP_CONFIG}/soft-build/ariane/sysroot/lib/libpthread-2.26.so"
# cp "$GLIBC_BUILD_DIR"/libc.so "$DESTINATION"/lib/libc-2.26.so

if [ $BOOT_BOARD -eq 1 ]; then
    cd $ESP_DIR
    source /scratch/shanboz2/spandex_env_global

    if [ $BUILD_EXAMPLE -eq 1 ]; then
        for example in "${EXAMPLE[@]}"; do
            for d in $(ls -d $ESP_DIR/soft/ariane/virtual-acc-app/examples/*/); do
                if [[ "$d" == *"$example"* ]]; then
                    FULL_EXAMPLE+=("$d")
                    break
                fi
            done
        done

        for example in "${FULL_EXAMPLE[@]}"; do
            echo "Building example: $example"
            cd $example
            sed -i "66c ESP_EXE_DIR = $\(ESP_ROOT\)/socs/$ESP_CONFIG/soft-build/ariane/sysroot/applications/test" ../../Makefile
            make clean > /dev/null
            make -j `nproc` > /dev/null
            cd $ESP_DIR
        done
    fi

    cd socs/$ESP_CONFIG
    make linux -j `nproc` > /dev/null 2>&1
    make fpga-program fpga-run-linux
    cd $PWD
fi
