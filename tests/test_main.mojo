"""
tests/test_main.mojo – Integration test for rapidgzip Mojo FFI.

Run (from project root):
    LD_LIBRARY_PATH=. pixi run mojo run -I . tests/test_main.mojo
    LD_LIBRARY_PATH=. pixi run mojo run -I . tests/test_main.mojo tests/testdata/sample.gz
"""

from rapidgzip import RapidgzipFile, shim_version
from std.sys import argv
from std.sys.terminate import exit
from std.os.path import exists


fn main() raises:
    var failed = False

    # 1. Version check – always runs
    var ver = shim_version()
    print("rapidgzip shim version:", ver)
    if len(ver) == 0:
        print("FAIL: shim_version returned empty")
        failed = True

    # 2. File I/O test if path provided or sample.gz exists
    var test_path: Optional[String] = None
    var args = argv()
    if len(args) >= 2:
        test_path = String(args[1])
    else:
        # Try default fixture
        var default_path = "tests/testdata/sample.gz"
        if exists(default_path):
            test_path = String(default_path)

    if test_path:
        var path = test_path[]
        try:
            var f = RapidgzipFile.open(path, parallelism=0)
            f.build_index()
            var sz = f.uncompressed_size()
            print("Uncompressed size:", sz, "bytes")

            f.seek(0)
            var buf = List[UInt8](capacity=256)
            var n = f.read(
                buf.unsafe_ptr().unsafe_mut_cast[True]().unsafe_origin_cast[MutExternalOrigin](),
                256,
            )
            print("Read", n, "bytes")
            f.close()
        except e:
            print("FAIL:", e)
            failed = True
    else:
        print("(No .gz file – run with tests/testdata/sample.gz to test file I/O)")

    if failed:
        exit(1)
    print("All tests passed.")
