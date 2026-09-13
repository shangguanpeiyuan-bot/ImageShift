import '../jobs/cancellation_token.dart';
import '../model/media.dart';

typedef ProgressCallback = void Function(MediaProgress progress);

abstract interface class MediaBackend {
  String get id;
  Future<MediaProbe> probe(String path, CancellationToken cancellation);
  bool supports(MediaProbe input, MediaJob job);
  Future<MediaResult> execute(
    MediaJob job,
    MediaProbe input,
    CancellationToken cancellation,
    ProgressCallback onProgress,
  );
}
