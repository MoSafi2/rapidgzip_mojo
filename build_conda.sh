#!/usr/bin/env bash
#
# Conda build script for rapidgzip-mojo.
# Builds librapidgzip_shim.so and rapidgzip.mojopkg, installs to $PREFIX.
#
# Expects: SRC_DIR (source root), PREFIX (install prefix), CXX (compiler)
#

set -e

# SRC_DIR is where the source is copied in rattler-build; RECIPE_DIR has the recipe
SRC_DIR="${SRC_DIR:-${RECIPE_DIR}}"
SCRIPT_DIR="${RECIPE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

RAPIDGZIP_VERSION="rapidgzip-v0.13.3"
RAPIDGZIP_ARCHIVE="${RAPIDGZIP_VERSION}.tar.gz"
RAPIDGZIP_URL="https://github.com/mxmlnkn/rapidgzip/archive/refs/tags/${RAPIDGZIP_ARCHIVE}"
DEPS_DIR="${SRC_DIR}/.deps"
RAPIDGZIP_SRC="${DEPS_DIR}/rapidgzip"

# Download rapidgzip if not present
if [[ ! -d "${RAPIDGZIP_SRC}" ]]; then
    echo "Downloading rapidgzip ${RAPIDGZIP_VERSION}..."
    mkdir -p "${DEPS_DIR}"
    curl -sL "${RAPIDGZIP_URL}" | tar xz -C "${DEPS_DIR}"
    mv "${DEPS_DIR}/rapidgzip-${RAPIDGZIP_VERSION}" "${RAPIDGZIP_SRC}"
fi

RAPIDGZIP_INCLUDE="${RAPIDGZIP_SRC}/src"
if [[ ! -d "${RAPIDGZIP_INCLUDE}" ]]; then
    echo "Error: rapidgzip src not found at ${RAPIDGZIP_INCLUDE}"
    exit 1
fi

# Build shared library (linux: .so, macos: .dylib)
if [[ "$(uname -s)" == "Darwin" ]]; then
    OUTPUT_LIB="${SRC_DIR}/librapidgzip_shim.dylib"
else
    OUTPUT_LIB="${SRC_DIR}/librapidgzip_shim.so"
fi

echo "Building ${OUTPUT_LIB}..."
${CXX} -std=c++17 -O3 -fPIC -shared -fconstexpr-ops-limit=134217728 \
    -I"${PREFIX}/include" \
    -I"${RAPIDGZIP_INCLUDE}" \
    -I"${RAPIDGZIP_INCLUDE}/rapidgzip" \
    -I"${RAPIDGZIP_INCLUDE}/core" \
    -I"${RAPIDGZIP_INCLUDE}/huffman" \
    -I"${RAPIDGZIP_INCLUDE}/indexed_bzip2" \
    -o "${OUTPUT_LIB}" \
    "${SRC_DIR}/rapidgzip_shim.cpp" \
    -lz -lpthread

echo "Built: ${OUTPUT_LIB}"

# Build Mojo package
echo "Building rapidgzip.mojopkg..."
cd "${SRC_DIR}"
mojo package rapidgzip -o rapidgzip.mojopkg

# Install to PREFIX
mkdir -p "${PREFIX}/lib"
mkdir -p "${PREFIX}/lib/mojo"

cp "${OUTPUT_LIB}" "${PREFIX}/lib/"
cp "${SRC_DIR}/rapidgzip.mojopkg" "${PREFIX}/lib/mojo/"

# Create minimal test script for conda test phase
cat > "${PREFIX}/lib/mojo/test_rapidgzip.mojo" << 'MOJO_EOF'
from rapidgzip import shim_version
fn main():
    print(shim_version())
MOJO_EOF

echo "Installed to ${PREFIX}/lib"
