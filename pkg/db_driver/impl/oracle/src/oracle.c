#include "oracle.h"

// Go (c-archive) exported functions.
extern int64_t oraclego_open(const char* dsn, char** err_out);
extern void oraclego_close(int64_t handle);
extern int64_t oraclego_query_open(int64_t handle, const char* sql, char** err_out);
extern void oraclego_query_close(int64_t query_handle);
extern oracle_query_header_t* oraclego_query_header(int64_t query_handle,
                                                    char** err_out);
extern oracle_query_batch_t* oraclego_query_next_batch(int64_t query_handle,
                                                       int32_t batch_size,
                                                       char** err_out);
extern void oraclego_query_free_header(oracle_query_header_t* header);
extern void oraclego_query_free_batch(oracle_query_batch_t* batch);

FFI_PLUGIN_EXPORT int64_t oracle_open(const char* dsn, char** err_out) {
  return oraclego_open(dsn, err_out);
}

FFI_PLUGIN_EXPORT void oracle_close(int64_t handle) { oraclego_close(handle); }

FFI_PLUGIN_EXPORT int64_t oracle_query_open(int64_t handle,
                                            const char* sql,
                                            char** err_out) {
  return oraclego_query_open(handle, sql, err_out);
}

FFI_PLUGIN_EXPORT void oracle_query_close(int64_t query_handle) {
  oraclego_query_close(query_handle);
}

FFI_PLUGIN_EXPORT oracle_query_header_t* oracle_query_header(int64_t query_handle,
                                                             char** err_out) {
  return oraclego_query_header(query_handle, err_out);
}

FFI_PLUGIN_EXPORT oracle_query_batch_t* oracle_query_next_batch(
    int64_t query_handle,
    int32_t batch_size,
    char** err_out) {
  return oraclego_query_next_batch(query_handle, batch_size, err_out);
}

FFI_PLUGIN_EXPORT void oracle_free_string(char* s) {
  if (s == NULL) return;
  free(s);
}

FFI_PLUGIN_EXPORT void oracle_query_free_header(oracle_query_header_t* header) {
  oraclego_query_free_header(header);
}

FFI_PLUGIN_EXPORT void oracle_query_free_batch(oracle_query_batch_t* batch) {
  oraclego_query_free_batch(batch);
}
