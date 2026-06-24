// Copyright 2025-present the zvec project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'zvec_bindings.dart' show zvec_error_code_t;
import 'zvec_library.dart';

/// Error codes returned by the Zvec C API.
enum ZvecErrorCode {
  ok(0),
  notFound(1),
  alreadyExists(2),
  invalidArgument(3),
  permissionDenied(4),
  failedPrecondition(5),
  resourceExhausted(6),
  unavailable(7),
  internalError(8),
  notSupported(9),
  unknown(10);

  const ZvecErrorCode(this.value);
  final int value;

  static ZvecErrorCode fromValue(int v) => ZvecErrorCode.values.firstWhere(
    (e) => e.value == v,
    orElse: () => ZvecErrorCode.unknown,
  );
}

/// Exception thrown when a Zvec C API call fails.
class ZvecException implements Exception {
  ZvecException(this.code, [this.message]);

  /// The error code from the C API.
  final ZvecErrorCode code;

  /// Optional error message with details.
  final String? message;

  @override
  String toString() {
    final msg = message != null ? ': $message' : '';
    return 'ZvecException(${code.name}$msg)';
  }
}

/// Check the return code from a C API call and throw [ZvecException] on error.
///
/// Accepts the [zvec_error_code_t] enum returned by generated bindings.
void checkError(zvec_error_code_t code) {
  if (code == zvec_error_code_t.ZVEC_OK) return;

  final bindings = ZvecLibrary.bindings;
  final errorCode = ZvecErrorCode.fromValue(code.value);

  // Try to get detailed error message
  final msgPtr = calloc<Pointer<Char>>();
  try {
    bindings.zvec_get_last_error(msgPtr);
    String? msg;
    if (msgPtr.value != nullptr) {
      msg = msgPtr.value.cast<Utf8>().toDartString();
      bindings.zvec_free(msgPtr.value.cast());
    }
    throw ZvecException(errorCode, msg);
  } finally {
    calloc.free(msgPtr);
  }
}
