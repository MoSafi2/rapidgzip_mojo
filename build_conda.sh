#!/usr/bin/env bash
set -euo pipefail

echo "Building rapidgzip-mojo for ${target_platform:-unknown}"

# Source directory (rattler sets this automatically)
SRC_DIR="${SRC_DIR:-$PWD}"
PREFIX="${PREFIX:-/usr/local}"

# Rapidgzip source
RAPIDGZIP_SRC="${SRC_DIR}/rapidgzip"
LIBRARY_SRC="${RAPIDGZIP_SRC}/librapidarchive"

# GitHub tarballs omit submodules; we fetch librapidarchive (indexed_bzip2) as a separate source.
# It extracts as librapidarchive/indexed_bzip2-<sha>/ — flatten so librapidarchive/src exists.
if [[ -d "${LIBRARY_SRC}" ]]; then
    SUBDIR=$(find "${LIBRARY_SRC}" -maxdepth 1 -mindepth 1 -type d | head -1)
    if [[ -n "${SUBDIR}" && ! -d "${LIBRARY_SRC}/src" ]]; then
        echo "Flattening librapidarchive from ${SUBDIR}..."
        for f in "${SUBDIR}"/* "${SUBDIR}"/.*; do
            [[ -e "${f}" && "${f}" != "${SUBDIR}/." && "${f}" != "${SUBDIR}/.." ]] && mv "${f}" "${LIBRARY_SRC}/" || true
        done 2>/dev/null || true
        rm -rf "${SUBDIR}"
    fi
fi

# Include path: use librapidarchive/src directly (C++ headers live there)
RAPIDGZIP_INCLUDE="${LIBRARY_SRC}/src"
if [[ ! -d "${RAPIDGZIP_INCLUDE}" ]]; then
    RAPIDGZIP_INCLUDE="${RAPIDGZIP_SRC}/src"
fi
if [[ ! -d "${RAPIDGZIP_INCLUDE}" ]]; then
    echo "Error: rapidgzip sources missing (no librapidarchive/src or rapidgzip/src)"
    echo "Make sure the recipe provides rapidgzip and librapidarchive (indexed_bzip2) sources."
    exit 1
fi

# Determine shared library extension
case "${target_platform:-$(uname -s)}" in
    osx-*) LIB_EXT="dylib" ;;
    linux-*) LIB_EXT="so" ;;
    *)
        echo "Unsupported platform: ${target_platform}"
        exit 1
        ;;
esac

OUTPUT_LIB="${SRC_DIR}/librapidgzip_shim.${LIB_EXT}"

echo "Using compiler: ${CXX:-g++}"
echo "CXXFLAGS: ${CXXFLAGS:-}"
echo "LDFLAGS: ${LDFLAGS:-}"

case "${target_platform}" in
    linux-*)
        CONSTEXPR_FLAG="-fconstexpr-ops-limit=134217728"
        ;;
    *)
        CONSTEXPR_FLAG=""
        ;;
esac

# Build the shared library
echo "Building ${OUTPUT_LIB}..."
${CXX} \
    ${CXXFLAGS} \
    -std=c++17 \
    -fPIC \
    -shared \
    ${CONSTEXPR_FLAG} \
    -I"${PREFIX}/include" \
    -I"${RAPIDGZIP_INCLUDE}" \
    -I"${RAPIDGZIP_INCLUDE}/rapidgzip" \
    -I"${RAPIDGZIP_INCLUDE}/core" \
    -I"${RAPIDGZIP_INCLUDE}/huffman" \
    -I"${RAPIDGZIP_INCLUDE}/indexed_bzip2" \
    "${SRC_DIR}/rapidgzip_shim.cpp" \
    ${LDFLAGS} \
    -L"${PREFIX}/lib" \
    -lz \
    -o "${OUTPUT_LIB}"
    
echo "Shared library built: ${OUTPUT_LIB}"

# Build Mojo package
echo "Packaging rapidgzip.mojopkg..."
cd "${SRC_DIR}"
mojo package rapidgzip -o rapidgzip.mojopkg

# Install files
mkdir -p "${PREFIX}/lib"
mkdir -p "${PREFIX}/lib/mojo"

cp "${OUTPUT_LIB}" "${PREFIX}/lib/"
cp rapidgzip.mojopkg "${PREFIX}/lib/mojo/"

# Minimal test script for conda test phase
cat > "${PREFIX}/lib/mojo/test_rapidgzip.mojo" << 'EOF'
from rapidgzip import shim_version
fn main():
    print(shim_version())
EOF

echo "Installation complete for ${target_platform}."