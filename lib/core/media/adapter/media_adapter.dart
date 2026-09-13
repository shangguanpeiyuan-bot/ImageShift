import '../jobs/cancellation_token.dart';
import '../model/media.dart';

class AdapterMatch {
  const AdapterMatch(this.confidence);
  final double confidence;
}

class PreparedMedia {
  PreparedMedia(
    this.primaryPath, {
    List<String> additionalPaths = const [],
    this.suggestedName,
    this.cleanup,
  }) : additionalPaths = List.unmodifiable(additionalPaths);
  final String primaryPath;
  final List<String> additionalPaths;
  final String? suggestedName;
  final Future<void> Function()? cleanup;
}

abstract interface class MediaAdapter {
  String get id;
  Future<AdapterMatch?> inspect(String path, CancellationToken cancellation);
  Future<PreparedMedia> prepare(String path, CancellationToken cancellation);
}

class AdapterRegistry {
  AdapterRegistry(Iterable<MediaAdapter> adapters)
    : adapters = List.unmodifiable(adapters) {
    if (this.adapters.map((a) => a.id).toSet().length != this.adapters.length) {
      throw ArgumentError('Duplicate adapter id');
    }
  }
  final List<MediaAdapter> adapters;

  Future<MediaAdapter?> match(String path, CancellationToken token) async {
    MediaAdapter? best;
    double confidence = 0;
    var ambiguous = false;
    for (final adapter in adapters) {
      token.throwIfCancelled();
      final match = await adapter.inspect(path, token);
      if (match == null) continue;
      final score = match.confidence;
      if (!score.isFinite || score < 0 || score > 1) {
        throw StateError('Invalid adapter confidence: ${adapter.id}');
      }
      if (score > confidence) {
        best = adapter;
        confidence = score;
        ambiguous = false;
      } else if (score > 0 && score == confidence) {
        ambiguous = true;
      }
    }
    if (ambiguous) {
      throw const MediaError(
        MediaErrorCode.unsupportedFormat,
        '文件结构匹配多个格式，无法可靠识别。',
      );
    }
    return best;
  }
}
