"""
rapidgzip – Mojo FFI bindings for the rapidgzip C shim.

Usage:
    from rapidgzip import RapidgzipFile, decompress_buffer, decompress_alloc
"""

from std.ffi import OwnedDLHandle, CStringSlice
from std.sys.info import platform_map
from std.memory import UnsafePointer, memcpy, MutOpaquePointer, alloc
from std.collections.string import StringSlice

# ─────────────────────────────────────────────────────────────
# Error codes (mirror rapidgzip_shim.h)
# ─────────────────────────────────────────────────────────────


# @fieldwise_init
# @register_passable("trivial")
# struct RapidgzipError(Copyable, Equatable, Movable, Writable):
#     var code: Int32

#     comptime OK = Self(0)
#     comptime NULL_PTR = Self(-1)
#     comptime OPEN_FAILED = Self(-2)
#     comptime READ_FAILED = Self(-3)
#     comptime SEEK_FAILED = Self(-4)
#     comptime DECOMP = Self(-5)
#     comptime INDEX = Self(-6)
#     comptime OOM = Self(-7)
#     comptime INVALID_ARG = Self(-8)
#     fn __eq__(self, other: Self) -> Bool:
#         return self.code == other.code


comptime RAPIDGZIP_OK               =  0
comptime RAPIDGZIP_ERR_NULL_PTR     = -1
comptime RAPIDGZIP_ERR_OPEN_FAILED  = -2
comptime RAPIDGZIP_ERR_READ_FAILED  = -3
comptime RAPIDGZIP_ERR_SEEK_FAILED  = -4
comptime RAPIDGZIP_ERR_DECOMP       = -5
comptime RAPIDGZIP_ERR_INDEX        = -6
comptime RAPIDGZIP_ERR_OOM          = -7
comptime RAPIDGZIP_ERR_INVALID_ARG  = -8

# Type aliases for FFI: opaque handle and pointers with external origin
comptime Handle = MutOpaquePointer[MutExternalOrigin]
comptime CharPtr = UnsafePointer[Int8, MutExternalOrigin]
comptime BytePtr = UnsafePointer[UInt8, MutExternalOrigin]
comptime IntPtr = UnsafePointer[Int, MutExternalOrigin]

# ─────────────────────────────────────────────────────────────
# RapidgzipLib: struct that loads the shared library dynamically
# and exposes FFI calls as methods
# ─────────────────────────────────────────────────────────────

struct RapidgzipLib(Movable):
    """Loads librapidgzip_shim dynamically and provides FFI method bindings."""

    var _lib: OwnedDLHandle

    fn __moveinit__(out self, deinit take: Self):
        self._lib = take._lib^

    @staticmethod
    fn _lib_name() -> String:
        """Return platform-specific shared library name."""
        return String(
            platform_map[
                "librapidgzip_shim",
                linux="librapidgzip_shim.so",
                macos="librapidgzip_shim.dylib",
            ]()
        )

    fn __init__(out self) raises:
        self._lib = OwnedDLHandle(self._lib_name())

    fn open(
        self,
        path: UnsafePointer[Int8, ImmutExternalOrigin],
        parallelism: UInt32,
        out_handle: UnsafePointer[Handle, MutExternalOrigin],
    ) -> Int32:
        return self._lib.call[
            "rapidgzip_open",
            Int32,
            UnsafePointer[Int8, ImmutExternalOrigin],
            UInt32,
            UnsafePointer[Handle, MutExternalOrigin],
        ](path, parallelism, out_handle)

    fn close(self, handle: Handle) -> None:
        _ = self._lib.call["rapidgzip_close", NoneType, Handle](handle)

    fn read(
        self,
        handle: Handle,
        buf: BytePtr,
        count: Int,
    ) -> Int64:
        return self._lib.call[
            "rapidgzip_read",
            Int64,
            Handle,
            BytePtr,
            Int,
        ](handle, buf, count)

    fn seek(self, handle: Handle, offset: Int64) -> Int32:
        return self._lib.call[
            "rapidgzip_seek", Int32, Handle, Int64
        ](handle, offset)

    fn tell(self, handle: Handle) -> Int64:
        return self._lib.call["rapidgzip_tell", Int64, Handle](handle)

    fn uncompressed_size(self, handle: Handle) -> Int64:
        return self._lib.call[
            "rapidgzip_uncompressed_size", Int64, Handle
        ](handle)

    fn decompress_buffer(
        self,
        in_buf: UnsafePointer[UInt8, ImmutExternalOrigin],
        in_size: Int,
        out_buf: BytePtr,
        out_capacity: Int,
        out_written: IntPtr,
        parallelism: UInt32,
    ) -> Int32:
        return self._lib.call[
            "rapidgzip_decompress_buffer",
            Int32,
            UnsafePointer[UInt8, ImmutExternalOrigin],
            Int,
            BytePtr,
            Int,
            IntPtr,
            UInt32,
        ](in_buf, in_size, out_buf, out_capacity, out_written, parallelism)

    fn decompress_alloc(
        self,
        in_buf: UnsafePointer[UInt8, ImmutExternalOrigin],
        in_size: Int,
        out_size: IntPtr,
        parallelism: UInt32,
    ) -> BytePtr:
        return self._lib.call[
            "rapidgzip_decompress_alloc",
            BytePtr,
            UnsafePointer[UInt8, ImmutExternalOrigin],
            Int,
            IntPtr,
            UInt32,
        ](in_buf, in_size, out_size, parallelism)

    fn free(self, ptr: BytePtr) -> None:
        _ = self._lib.call["rapidgzip_free", NoneType, BytePtr](ptr)

    fn build_index(self, handle: Handle) -> Int32:
        return self._lib.call["rapidgzip_build_index", Int32, Handle](handle)

    fn export_index(
        self,
        handle: Handle,
        out_data: UnsafePointer[BytePtr, MutExternalOrigin],
        out_size: IntPtr,
    ) -> Int32:
        return self._lib.call[
            "rapidgzip_export_index",
            Int32,
            Handle,
            UnsafePointer[BytePtr, MutExternalOrigin],
            IntPtr,
        ](handle, out_data, out_size)

    fn import_index(
        self,
        handle: Handle,
        data: UnsafePointer[UInt8, ImmutExternalOrigin],
        size: Int,
    ) -> Int32:
        return self._lib.call[
            "rapidgzip_import_index",
            Int32,
            Handle,
            UnsafePointer[UInt8, ImmutExternalOrigin],
            Int,
        ](handle, data, size)

    fn strerror(self, err: Int32) -> UnsafePointer[Int8, MutExternalOrigin]:
        return self._lib.call[
            "rapidgzip_strerror",
            UnsafePointer[Int8, MutExternalOrigin],
            Int32,
        ](err)

    fn shim_version(self) -> UnsafePointer[Int8, MutExternalOrigin]:
        return self._lib.call[
            "rapidgzip_shim_version",
            UnsafePointer[Int8, MutExternalOrigin],
        ]()


# ─────────────────────────────────────────────────────────────
# Error handling helper
# ─────────────────────────────────────────────────────────────

fn _error_msg(ref lib: RapidgzipLib, code: Int32) -> String:
    """Convert error code to human-readable string."""
    var msg_ptr = lib.strerror(code)
    if not msg_ptr:
        return String("Unknown error")
    var cstr = CStringSlice(unsafe_from_ptr=msg_ptr)
    return String(StringSlice(unsafe_from_utf8=cstr.as_bytes()))

# ─────────────────────────────────────────────────────────────
# High-level RapidgzipFile struct
# ─────────────────────────────────────────────────────────────

struct RapidgzipFile(Movable):
    """Parallel gzip file reader wrapping the C shim."""

    var _lib: RapidgzipLib
    var _handle: Handle

    # ── Construction / destruction ────────────────────────────


    fn __init__(out self) raises:
        """Default (invalid) construction – use open() instead."""
        self._lib = RapidgzipLib()
        self._handle = Handle(unsafe_from_address=0)

    @staticmethod
    fn open(
        path: String, parallelism: UInt32 = 0
    ) raises -> RapidgzipFile:
        """
        Open `path` for parallel decompression.

        Args:
            path:        Filesystem path to a .gz file.
            parallelism: Number of worker threads; 0 = auto-detect.

        Raises:
            Error if the file cannot be opened.
        """
        var self_ = RapidgzipFile()
        var path_mut = path
        var path_cstr = path_mut.as_c_string_slice()
        var handle_ptr = Handle(unsafe_from_address=0)
        var handle_out = alloc[Handle](1)
        handle_out[0] = handle_ptr

        var rc = self_._lib.open(
            path_cstr.unsafe_ptr().unsafe_origin_cast[ImmutExternalOrigin](),
            parallelism,
            handle_out,
        )
        if rc != RAPIDGZIP_OK:
            handle_out.free()
            raise Error(
                "rapidgzip_open failed: " + _error_msg(self_._lib, rc)
            )

        self_._handle = handle_out[0]
        handle_out.free()
        return self_^

    fn close(mut self):
        """Close the file and release all resources."""
        if self._handle:
            self._lib.close(self._handle)
            self._handle = Handle(unsafe_from_address=0)

    fn __del__(deinit self):
        self.close()

    # ── I/O ──────────────────────────────────────────────────

    fn read(self, buf: BytePtr, count: Int) raises -> Int:
        """
        Read up to `count` decompressed bytes into `buf`.

        Returns:
            Number of bytes actually read (0 = EOF).
        """
        var n = self._lib.read(self._handle, buf, count)
        if n < 0:
            raise Error(
                "rapidgzip_read failed: " + _error_msg(self._lib, Int32(n))
            )
        return Int(n)

    fn seek(self, offset: Int64) raises:
        """Seek to a decompressed byte offset (index must be built first)."""
        var rc = self._lib.seek(self._handle, offset)
        if rc != RAPIDGZIP_OK:
            raise Error(
                "rapidgzip_seek failed: " + _error_msg(self._lib, rc)
            )

    fn tell(self) -> Int64:
        """Return current decompressed read position."""
        return self._lib.tell(self._handle)

    fn uncompressed_size(self) -> Int64:
        """
        Return uncompressed file size, or -1 if not yet known.
        Building the index first guarantees a valid result.
        """
        return self._lib.uncompressed_size(self._handle)

    # ── Index ─────────────────────────────────────────────────

    fn build_index(self) raises:
        """Build the random-access index (enables seek)."""
        var rc = self._lib.build_index(self._handle)
        if rc != RAPIDGZIP_OK:
            raise Error(
                "rapidgzip_build_index failed: " + _error_msg(self._lib, rc)
            )

    fn export_index(self) raises -> List[UInt8]:
        """Serialise the index to a byte list for later import."""
        var out_ptr_storage = alloc[BytePtr](1)
        out_ptr_storage[0] = BytePtr(unsafe_from_address=0)
        var out_size_storage = alloc[Int](1)
        out_size_storage[0] = 0
        var rc = self._lib.export_index(
            self._handle,
            out_ptr_storage,
            out_size_storage,
        )
        if rc != RAPIDGZIP_OK:
            out_ptr_storage.free()
            out_size_storage.free()
            raise Error(
                "rapidgzip_export_index failed: " + _error_msg(self._lib, rc)
            )
        var out_ptr = out_ptr_storage[0]
        var out_size = out_size_storage[0]
        out_ptr_storage.free()
        out_size_storage.free()
        var result = List[UInt8](capacity=out_size)
        for i in range(out_size):
            result.append(out_ptr[i])
        self._lib.free(out_ptr)
        return result^

    fn import_index(self, data: List[UInt8]) raises:
        """Load a previously exported index."""
        var rc = self._lib.import_index(
            self._handle,
            data.unsafe_ptr().unsafe_origin_cast[ImmutExternalOrigin](),
            len(data),
        )
        if rc != RAPIDGZIP_OK:
            raise Error(
                "rapidgzip_import_index failed: " + _error_msg(self._lib, rc)
            )

    # ── Convenience: read all ─────────────────────────────────

    fn read_all(self) raises -> List[UInt8]:
        """
        Read the entire file into a List[UInt8].
        If the uncompressed size is known, allocates exactly once.
        """
        var sz = self.uncompressed_size()
        var buf = List[UInt8]()

        if sz > 0:
            buf = List[UInt8](capacity=Int(sz))
            _ = self.read(
                buf.unsafe_ptr().unsafe_origin_cast[MutExternalOrigin](),
                Int(sz),
            )
        else:
            # Unknown size: chunked read
            var chunk = 65536
            var tmp = List[UInt8](capacity=chunk)
            while True:
                var n = self.read(
                    tmp.unsafe_ptr().unsafe_origin_cast[MutExternalOrigin](),
                    chunk,
                )
                if n == 0:
                    break
                for i in range(n):
                    buf.append(tmp[i])
        return buf^


# ─────────────────────────────────────────────────────────────
# Module-level convenience functions
# ─────────────────────────────────────────────────────────────

fn decompress_buffer(
    data: List[UInt8],
    output: List[UInt8],
    parallelism: UInt32 = 0,
) raises -> Int:
    """
    Decompress `data` into the caller-provided `out` buffer.

    Returns:
        Number of decompressed bytes written.
    """
    var lib = RapidgzipLib()
    var written_storage = alloc[Int](1)
    written_storage[0] = 0
    var rc = lib.decompress_buffer(
        data.unsafe_ptr().unsafe_origin_cast[ImmutExternalOrigin](),
        len(data),
        output.unsafe_ptr().unsafe_mut_cast[True]().unsafe_origin_cast[MutExternalOrigin](),
        len(output),
        written_storage,
        parallelism,
    )
    if rc != RAPIDGZIP_OK:
        written_storage.free()
        raise Error(
            "rapidgzip_decompress_buffer failed: " + _error_msg(lib, rc)
        )
    var written = written_storage[0]
    written_storage.free()
    return written


fn decompress_alloc(
    data: List[UInt8], parallelism: UInt32 = 0
) raises -> List[UInt8]:
    """
    Decompress `data`, returning a newly allocated List[UInt8].
    The library allocates the output buffer; we copy it into Mojo memory.
    """
    var lib = RapidgzipLib()
    var out_size_storage = alloc[Int](1)
    out_size_storage[0] = 0
    var ptr = lib.decompress_alloc(
        data.unsafe_ptr().unsafe_origin_cast[ImmutExternalOrigin](),
        len(data),
        out_size_storage,
        parallelism,
    )
    if not ptr:
        out_size_storage.free()
        raise Error("rapidgzip_decompress_alloc returned null")

    var out_size = out_size_storage[0]
    out_size_storage.free()
    var result = List[UInt8](capacity=out_size)
    for i in range(out_size):
        result.append(ptr[i])
    lib.free(ptr)
    return result^


fn shim_version() raises -> String:
    """Return the C shim version string."""
    var lib = RapidgzipLib()
    var ptr = lib.shim_version()
    if not ptr:
        return String("unknown")
    var cstr = CStringSlice(unsafe_from_ptr=ptr)
    return String(StringSlice(unsafe_from_utf8=cstr.as_bytes()))
