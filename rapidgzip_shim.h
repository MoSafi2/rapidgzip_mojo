#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

/* ─────────────────────────────────────────────
 * Opaque handle types
 * ───────────────────────────────────────────── */
typedef struct RapidgzipFile_   RapidgzipFile;
typedef struct RapidgzipIndex_  RapidgzipIndex;

/* ─────────────────────────────────────────────
 * Error codes
 * ───────────────────────────────────────────── */
typedef enum {
    RAPIDGZIP_OK               =  0,
    RAPIDGZIP_ERR_NULL_PTR     = -1,
    RAPIDGZIP_ERR_OPEN_FAILED  = -2,
    RAPIDGZIP_ERR_READ_FAILED  = -3,
    RAPIDGZIP_ERR_SEEK_FAILED  = -4,
    RAPIDGZIP_ERR_DECOMP       = -5,
    RAPIDGZIP_ERR_INDEX        = -6,
    RAPIDGZIP_ERR_OOM          = -7,
    RAPIDGZIP_ERR_INVALID_ARG  = -8,
} RapidgzipError;

/* ─────────────────────────────────────────────
 * File-level API
 * ───────────────────────────────────────────── */

/**
 * Open a gzip-compressed file for parallel decompression.
 *
 * @param path          Null-terminated filesystem path.
 * @param parallelism   Number of worker threads (0 = auto).
 * @param out_handle    Receives the opaque file handle on success.
 * @return              RAPIDGZIP_OK or a negative error code.
 */
RapidgzipError rapidgzip_open(
    const char      *path,
    uint32_t         parallelism,
    RapidgzipFile  **out_handle
);

/**
 * Close a previously opened handle and free all resources.
 * Passing NULL is safe (no-op).
 */
void rapidgzip_close(RapidgzipFile *handle);

/**
 * Read up to `count` decompressed bytes into `buf`.
 *
 * @return Number of bytes actually read, or a negative error code.
 */
int64_t rapidgzip_read(
    RapidgzipFile *handle,
    void          *buf,
    size_t         count
);

/**
 * Seek to a decompressed byte offset.
 * Only supported when an index has been built or imported.
 *
 * @return RAPIDGZIP_OK or a negative error code.
 */
RapidgzipError rapidgzip_seek(
    RapidgzipFile *handle,
    int64_t        offset
);

/**
 * Return the current decompressed read position, or -1 on error.
 */
int64_t rapidgzip_tell(RapidgzipFile *handle);

/**
 * Query the uncompressed size (requires full-file scan or index).
 * Returns -1 if not yet known.
 */
int64_t rapidgzip_uncompressed_size(RapidgzipFile *handle);

/* ─────────────────────────────────────────────
 * In-memory buffer API
 * ───────────────────────────────────────────── */

/**
 * Decompress an entire gzip buffer in one call.
 *
 * @param in_buf        Compressed input bytes.
 * @param in_size       Size of compressed input.
 * @param out_buf       Caller-allocated output buffer.
 * @param out_capacity  Size of output buffer.
 * @param out_written   Receives number of decompressed bytes written.
 * @param parallelism   Worker threads (0 = auto).
 * @return              RAPIDGZIP_OK or a negative error code.
 */
RapidgzipError rapidgzip_decompress_buffer(
    const void *in_buf,
    size_t      in_size,
    void       *out_buf,
    size_t      out_capacity,
    size_t     *out_written,
    uint32_t    parallelism
);

/**
 * Decompress an entire gzip buffer, allocating the output internally.
 * The caller MUST free the returned pointer with rapidgzip_free().
 *
 * @param in_buf        Compressed input bytes.
 * @param in_size       Size of compressed input.
 * @param out_size      Receives the size of the allocated output buffer.
 * @param parallelism   Worker threads (0 = auto).
 * @return              Pointer to decompressed data, or NULL on error.
 */
void *rapidgzip_decompress_alloc(
    const void *in_buf,
    size_t      in_size,
    size_t     *out_size,
    uint32_t    parallelism
);

/**
 * Free a buffer allocated by rapidgzip_decompress_alloc().
 */
void rapidgzip_free(void *ptr);

/* ─────────────────────────────────────────────
 * Index API
 * ───────────────────────────────────────────── */

/**
 * Build a random-access index for an open file.
 * Required before rapidgzip_seek() can be called.
 *
 * @return RAPIDGZIP_OK or a negative error code.
 */
RapidgzipError rapidgzip_build_index(RapidgzipFile *handle);

/**
 * Export the index to a byte buffer allocated internally.
 * Free with rapidgzip_free().
 *
 * @param out_data  Receives pointer to serialised index bytes.
 * @param out_size  Receives size of serialised index.
 * @return          RAPIDGZIP_OK or a negative error code.
 */
RapidgzipError rapidgzip_export_index(
    RapidgzipFile  *handle,
    void          **out_data,
    size_t         *out_size
);

/**
 * Import a previously exported index into an open file handle.
 *
 * @return RAPIDGZIP_OK or a negative error code.
 */
RapidgzipError rapidgzip_import_index(
    RapidgzipFile *handle,
    const void    *data,
    size_t         size
);

/* ─────────────────────────────────────────────
 * Utility
 * ───────────────────────────────────────────── */

/** Return a human-readable string for an error code. */
const char *rapidgzip_strerror(RapidgzipError err);

/** Return the shim's version string, e.g. "0.1.0". */
const char *rapidgzip_shim_version(void);

#ifdef __cplusplus
}  /* extern "C" */
#endif
