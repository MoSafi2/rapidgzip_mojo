/**
 * rapidgzip_shim.cpp
 *
 * Thin C-linkage wrapper around the rapidgzip C++ library.
 * Compile with C++17 or later.
 *
 * Link flags (example):
 *   -lrapidgzip -lz -lpthread
 */

 #include "rapidgzip_shim.h"

 #include <filereader/Standard.hpp>
 #include <filereader/BufferView.hpp>
 #include <rapidgzip/ParallelGzipReader.hpp>
 #include <rapidgzip/gzip/gzip.hpp>
 
 #include <algorithm>
 #include <cstdlib>
 #include <cstring>
 #include <limits>
 #include <memory>
 #include <new>
 #include <stdexcept>
 #include <string>
 #include <vector>
 
 /* ─────────────────────────────────────────────
  * Internal helpers
  * ───────────────────────────────────────────── */
 
 static constexpr char SHIM_VERSION[] = "0.1.0";
 
 // We store the actual C++ object inside the opaque struct.
 struct RapidgzipFile_ {
     std::unique_ptr<rapidgzip::ParallelGzipReader<>> reader;
     std::string path;
     uint32_t    parallelism{0};
     bool        index_built{false};
 };
 
 struct RapidgzipIndex_ {
     std::vector<uint8_t> data;
 };
 
 // Translate C++ exceptions → error codes.
 static RapidgzipError translate_exception() noexcept {
     try { throw; }
     catch (const std::bad_alloc &)         { return RAPIDGZIP_ERR_OOM; }
     catch (const std::invalid_argument &)  { return RAPIDGZIP_ERR_INVALID_ARG; }
     catch (const std::ios_base::failure &) { return RAPIDGZIP_ERR_READ_FAILED; }
     catch (...)                            { return RAPIDGZIP_ERR_DECOMP; }
 }
 
 /* ─────────────────────────────────────────────
  * File-level API
  * ───────────────────────────────────────────── */
 
 extern "C" RapidgzipError rapidgzip_open(
         const char      *path,
         uint32_t         parallelism,
         RapidgzipFile  **out_handle)
 {
     if (!path || !out_handle) return RAPIDGZIP_ERR_NULL_PTR;
     *out_handle = nullptr;
 
     try {
         auto *h = new (std::nothrow) RapidgzipFile_;
         if (!h) return RAPIDGZIP_ERR_OOM;
 
         h->path        = path;
         h->parallelism = parallelism ? parallelism
                                      : std::thread::hardware_concurrency();
 
         auto file_reader = std::make_unique<rapidgzip::StandardFileReader>(path);
         h->reader = std::make_unique<rapidgzip::ParallelGzipReader<>>(
             std::move(file_reader), h->parallelism);
 
         *out_handle = h;
         return RAPIDGZIP_OK;
     } catch (...) {
         return translate_exception();
     }
 }
 
 extern "C" void rapidgzip_close(RapidgzipFile *h)
 {
     delete h;
 }
 
 extern "C" int64_t rapidgzip_read(
         RapidgzipFile *h,
         void          *buf,
         size_t         count)
 {
     if (!h || !buf) return static_cast<int64_t>(RAPIDGZIP_ERR_NULL_PTR);
     try {
         return static_cast<int64_t>(
             h->reader->read(reinterpret_cast<char*>(buf), count));
     } catch (...) {
         return static_cast<int64_t>(translate_exception());
     }
 }
 
 extern "C" RapidgzipError rapidgzip_seek(RapidgzipFile *h, int64_t offset)
 {
     if (!h) return RAPIDGZIP_ERR_NULL_PTR;
     if (!h->index_built) return RAPIDGZIP_ERR_INDEX;
     try {
         h->reader->seek(static_cast<size_t>(offset));
         return RAPIDGZIP_OK;
     } catch (...) {
         return translate_exception();
     }
 }
 
 extern "C" int64_t rapidgzip_tell(RapidgzipFile *h)
 {
     if (!h) return -1;
     try {
         return static_cast<int64_t>(h->reader->tell());
     } catch (...) {
         return -1;
     }
 }
 
 extern "C" int64_t rapidgzip_uncompressed_size(RapidgzipFile *h)
 {
     if (!h) return -1;
     try {
         const auto sz = h->reader->size();
         return sz.has_value() ? static_cast<int64_t>(*sz) : -1;
     } catch (...) {
         return -1;
     }
 }
 
 /* ─────────────────────────────────────────────
  * In-memory buffer API
  * ───────────────────────────────────────────── */
 
 extern "C" RapidgzipError rapidgzip_decompress_buffer(
         const void *in_buf,
         size_t      in_size,
         void       *out_buf,
         size_t      out_capacity,
         size_t     *out_written,
         uint32_t    parallelism)
 {
     if (!in_buf || !out_buf || !out_written) return RAPIDGZIP_ERR_NULL_PTR;
     *out_written = 0;
 
     try {
         uint32_t nthreads = parallelism ? parallelism
                                         : std::thread::hardware_concurrency();
         auto mem_reader = std::make_unique<rapidgzip::BufferViewFileReader>(
             reinterpret_cast<const char*>(in_buf), in_size);
         rapidgzip::ParallelGzipReader<> reader(std::move(mem_reader), nthreads);
 
         size_t total = 0;
         while (total < out_capacity) {
             const size_t n = reader.read(
                 reinterpret_cast<char*>(out_buf) + total,
                 out_capacity - total);
             if (n == 0) break;
             total += n;
         }
         *out_written = total;
         return RAPIDGZIP_OK;
     } catch (...) {
         return translate_exception();
     }
 }
 
 extern "C" void *rapidgzip_decompress_alloc(
         const void *in_buf,
         size_t      in_size,
         size_t     *out_size,
         uint32_t    parallelism)
 {
     if (!in_buf || !out_size) return nullptr;
     *out_size = 0;
 
     try {
         uint32_t nthreads = parallelism ? parallelism
                                         : std::thread::hardware_concurrency();
         auto mem_reader = std::make_unique<rapidgzip::BufferViewFileReader>(
             reinterpret_cast<const char*>(in_buf), in_size);
         rapidgzip::ParallelGzipReader<> reader(std::move(mem_reader), nthreads);
 
         std::vector<char> result;
         result.reserve(in_size * 4);  // rough heuristic
         char tmp[65536];
         while (true) {
             const size_t n = reader.read(tmp, sizeof(tmp));
             if (n == 0) break;
             result.insert(result.end(), tmp, tmp + n);
         }
 
         void *ptr = std::malloc(result.size());
         if (!ptr) return nullptr;
         std::memcpy(ptr, result.data(), result.size());
         *out_size = result.size();
         return ptr;
     } catch (...) {
         return nullptr;
     }
 }
 
 extern "C" void rapidgzip_free(void *ptr)
 {
     std::free(ptr);
 }
 
 /* ─────────────────────────────────────────────
  * Index API
  * ───────────────────────────────────────────── */
 
 extern "C" RapidgzipError rapidgzip_build_index(RapidgzipFile *h)
 {
     if (!h) return RAPIDGZIP_ERR_NULL_PTR;
     try {
         h->reader->setKeepIndex(true);
         /* Read through entire file to build the index */
         h->reader->read(-1, nullptr, std::numeric_limits<size_t>::max());
         h->index_built = true;
         return RAPIDGZIP_OK;
     } catch (...) {
         return translate_exception();
     }
 }
 
 extern "C" RapidgzipError rapidgzip_export_index(
         RapidgzipFile  *h,
         void          **out_data,
         size_t         *out_size)
 {
     if (!h || !out_data || !out_size) return RAPIDGZIP_ERR_NULL_PTR;
     if (!h->index_built) return RAPIDGZIP_ERR_INDEX;
     *out_data = nullptr;
     *out_size = 0;
 
     try {
         std::vector<uint8_t> idx;
         h->reader->exportIndex(
             [&idx](const void* buffer, size_t size) {
                 const auto* p = static_cast<const uint8_t*>(buffer);
                 idx.insert(idx.end(), p, p + size);
             });
         void *ptr = std::malloc(idx.size());
         if (!ptr) return RAPIDGZIP_ERR_OOM;
         std::memcpy(ptr, idx.data(), idx.size());
         *out_data = ptr;
         *out_size = idx.size();
         return RAPIDGZIP_OK;
     } catch (...) {
         return translate_exception();
     }
 }
 
 extern "C" RapidgzipError rapidgzip_import_index(
         RapidgzipFile *h,
         const void    *data,
         size_t         size)
 {
     if (!h || !data) return RAPIDGZIP_ERR_NULL_PTR;
     try {
         auto index_reader = std::make_unique<rapidgzip::BufferViewFileReader>(
             reinterpret_cast<const char*>(data), size);
         h->reader->importIndex(std::move(index_reader));
         h->index_built = true;
         return RAPIDGZIP_OK;
     } catch (...) {
         return translate_exception();
     }
 }
 
 /* ─────────────────────────────────────────────
  * Utility
  * ───────────────────────────────────────────── */
 
 extern "C" const char *rapidgzip_strerror(RapidgzipError err)
 {
     switch (err) {
         case RAPIDGZIP_OK:              return "Success";
         case RAPIDGZIP_ERR_NULL_PTR:    return "Null pointer";
         case RAPIDGZIP_ERR_OPEN_FAILED: return "Failed to open file";
         case RAPIDGZIP_ERR_READ_FAILED: return "Read error";
         case RAPIDGZIP_ERR_SEEK_FAILED: return "Seek error";
         case RAPIDGZIP_ERR_DECOMP:      return "Decompression error";
         case RAPIDGZIP_ERR_INDEX:       return "Index error (not built?)";
         case RAPIDGZIP_ERR_OOM:         return "Out of memory";
         case RAPIDGZIP_ERR_INVALID_ARG: return "Invalid argument";
         default:                        return "Unknown error";
     }
 }
 
 extern "C" const char *rapidgzip_shim_version(void)
 {
     return SHIM_VERSION;
 }
