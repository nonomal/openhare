#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

// Value kind tags used in oracle_query_value_t.kind.
#define ORACLE_VALUE_NULL 0
#define ORACLE_VALUE_BYTES 1
#define ORACLE_VALUE_INT 2
#define ORACLE_VALUE_UINT 3
#define ORACLE_VALUE_FLOAT 4
#define ORACLE_VALUE_DOUBLE 5
#define ORACLE_VALUE_DATETIME 6
#define ORACLE_VALUE_STRING 7

typedef struct oracle_query_value_t {
  int32_t kind;
  int64_t int_value;
  uint64_t uint_value;
  float float_value;
  double double_value;
  int64_t datetime_value;
  uint8_t* bytes_value;
  int32_t bytes_len;
} oracle_query_value_t;

typedef struct oracle_query_row_t {
  oracle_query_value_t* values;
  int32_t value_count;
} oracle_query_row_t;

typedef struct oracle_query_column_t {
  char* name;
  char* column_type;
} oracle_query_column_t;

typedef struct oracle_query_header_t {
  oracle_query_column_t* columns;
  int32_t column_count;
  int64_t affected_rows;
} oracle_query_header_t;

typedef struct oracle_query_batch_t {
  oracle_query_row_t* rows;
  int32_t row_count;
  int32_t done;
} oracle_query_batch_t;

// Open an Oracle connection.
//
// Returns a non-zero handle on success.
// On error, returns 0 and sets *err_out to a newly allocated C string (free it via oracle_free_string).
FFI_PLUGIN_EXPORT int64_t oracle_open(const char* dsn, char** err_out);

// Close a connection handle (no-op if handle is invalid/closed).
FFI_PLUGIN_EXPORT void oracle_close(int64_t handle);

// Open a query cursor and return a non-zero query handle on success.
// On error, returns 0 and sets *err_out to a newly allocated C string.
FFI_PLUGIN_EXPORT int64_t oracle_query_open(int64_t handle, const char* sql, char** err_out);

// Close a query cursor handle.
FFI_PLUGIN_EXPORT void oracle_query_close(int64_t query_handle);

// Fetch query header struct.
FFI_PLUGIN_EXPORT oracle_query_header_t* oracle_query_header(
    int64_t query_handle, char** err_out);

// Fetch next batch rows as struct.
FFI_PLUGIN_EXPORT oracle_query_batch_t* oracle_query_next_batch(
    int64_t query_handle, int32_t batch_size, char** err_out);

// Free a C string returned by this library.
FFI_PLUGIN_EXPORT void oracle_free_string(char* s);

// Free query header/batch structs returned by this library.
FFI_PLUGIN_EXPORT void oracle_query_free_header(oracle_query_header_t* header);
FFI_PLUGIN_EXPORT void oracle_query_free_batch(oracle_query_batch_t* batch);
