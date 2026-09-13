import '../backend/media_backend.dart';
import '../model/media.dart';
import 'cancellation_token.dart';
import 'resource_scheduler.dart';

class MediaJobEngine {
  MediaJobEngine({ResourceScheduler? scheduler})
    : scheduler = scheduler ?? ResourceScheduler();
  final ResourceScheduler scheduler;
  final Set<String> _running = {};

  Future<MediaResult> run(
    MediaJob job,
    MediaBackend backend,
    CancellationToken token, {
    ProgressCallback? onProgress,
  }) async {
    if (!_running.add(job.id)) {
      return MediaResult(
        jobId: job.id,
        stage: MediaStage.failed,
        error: const MediaError(MediaErrorCode.invalidParameters, '任务已在运行。'),
      );
    }
    void emit(MediaProgress progress) {
      onProgress?.call(progress);
    }

    try {
      emit(const MediaProgress(MediaStage.queued));
      return await scheduler.run(token, () async {
        emit(const MediaProgress(MediaStage.probing));
        final input = await backend.probe(job.inputPath, token);
        token.throwIfCancelled();
        if (!backend.supports(input, job)) {
          throw const MediaError(
            MediaErrorCode.unsupportedFormat,
            '当前后端不支持此转换。',
          );
        }
        final result = await backend.execute(job, input, token, emit);
        emit(MediaProgress(result.stage));
        return result;
      });
    } on MediaError catch (error) {
      final stage = error.code == MediaErrorCode.cancelled
          ? MediaStage.cancelled
          : MediaStage.failed;
      emit(MediaProgress(stage));
      return MediaResult(jobId: job.id, stage: stage, error: error);
    } catch (_) {
      emit(const MediaProgress(MediaStage.failed));
      return MediaResult(
        jobId: job.id,
        stage: MediaStage.failed,
        error: MediaError(
          MediaErrorCode.unknown,
          '媒体处理未能完成。',
          backend: backend.id,
        ),
      );
    } finally {
      _running.remove(job.id);
    }
  }
}
