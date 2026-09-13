enum ConversionErrorCode {
  invalidImage,
  corruptImage,
  unsupportedFormat,
  unsupportedSequence,
  readFailed,
  writeFailed,
  encodeFailed,
  invalidOptions,
  resourceLimit,
  unexpected,
}

/// Technical details are deliberately separate from user-facing Chinese text.
class ConversionError implements Exception {
  const ConversionError(this.code, this.message, {this.detail});
  final ConversionErrorCode code;
  final String message;
  final String? detail;

  @override
  String toString() => 'ConversionError(${code.name}): $message';
}
