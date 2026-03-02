# rapidgzip-mojo

Minimal Mojo FFI bindings for the [rapidgzip](https://github.com/mxmlnkn/rapidgzip) C++ library via a thin C shim. Provides parallel gzip decompression with `RapidgzipFile`, `decompress_buffer`, `decompress_alloc`, and index API.
It does not cover the whole public API for rapidgzip. for now it cover tha basic use cases of parallel sequential file decompression and indexing.

## Quick start

### Build conda package

```bash
pixi run build
```

or:

```bash
pixi build
```

This builds the conda package (`.conda` file) using the rattler-build recipe.

### Run tests

```bash
pixi run test
# With optional .gz file for file I/O test:
pixi run test -- tests/testdata/sample.gz
```

Install from the built package:

```bash
pixi add --path ./rapidgzip-mojo-*.conda
```

Or add as a dependency from Git (in another project's `pixi.toml`):

```toml
[dependencies]
rapidgzip-mojo = { git = "[https://github.com/MoSafi2/rapidgzip-mojo.git](https://github.com/MoSafi2/rapidgzip_mojo)", branch = "main" }
```

## Usage

```mojo
from rapidgzip import RapidgzipFile, decompress_alloc, decompress_buffer

# File-based decompression
var f = RapidgzipFile.open("data.gz", parallelism=0)
f.build_index()
var data = f.read_all()
f.close()

# In-memory decompression
var compressed: List[UInt8] = ...  # your gzip bytes
var decompressed = decompress_alloc(compressed, parallelism=0)
```

## Project layout

```
rapidgzip-mojo/
├── rapidgzip/__init__.mojo   # Mojo FFI bindings
├── rapidgzip_shim.cpp        # C shim
├── rapidgzip_shim.h
├── build_conda.sh            # Conda build script
├── recipe.yaml               # Rattler-build recipe
├── pixi.toml
└── tests/
    ├── test_main.mojo
    └── testdata/sample.gz
```

## Platform support

- **Linux:** `.so` (primary target)
- **macOS:** `.dylib` (platform detection in Mojo FFI)

Build script and conda recipe currently target linux-64; macOS-arm64 which are the current mojo targets.
Only linux-64 was tested but probably works on WSL2.
