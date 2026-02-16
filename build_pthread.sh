#!/usr/bin/env bash

TARGET_PREFIX=$(realpath ~/riscv)

INTERACTIVE=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            TARGET_PREFIX=$(realpath "$2")
            shift 2
            ;;
        --dest)
            DESTINATION=$(realpath "$2")
            shift 2
            ;;
        --no-interactive)
            INTERACTIVE=0
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

RISCV_GNU_TOOLCHAIN_ROOT=$(printenv RISCV_GNU_TOOLCHAIN_ROOT)
if [ -z "$RISCV_GNU_TOOLCHAIN_ROOT" ]; then
    RISCV_GNU_TOOLCHAIN_ROOT=$(pwd)
fi

RISCV_GNU_TOOLCHAIN_ROOT=$(realpath $RISCV_GNU_TOOLCHAIN_ROOT)
GLIBC_BUILD_DIR="$RISCV_GNU_TOOLCHAIN_ROOT/build-glibc-linux-rv64imafdc-lp64d"
CONFIGURE_SCRIPT="$RISCV_GNU_TOOLCHAIN_ROOT/riscv-glibc/configure"

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

build_target "nptl"

cp "$GLIBC_BUILD_DIR"/nptl/libpthread.so "$DESTINATION"
