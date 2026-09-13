import '../model/media.dart';

/// Conservative admission estimate, not a promise that native code cannot OOM.
/// Streamed JPEG/PNG/TIFF are not rejected solely because of their pixel count.
void checkImageResources(MediaProbe input, MediaJob job) {
  final budget = job.memoryBudgetBytes;
  if (budget == null) return;
  const baseline = 64 * 1024 * 1024;
  final materializes =
      input.format == 'webp' ||
      (job.imageTask?.edits.quarterTurns.isOdd ?? false);
  final estimate =
      baseline +
      (materializes ? (input.width ?? 0) * (input.height ?? 0) * 8 : 0);
  if (estimate > budget) {
    throw const MediaError(
      MediaErrorCode.resourceUnavailable,
      '当前可用内存不足以安全处理此图片，请关闭其他应用或选择较小的文件。',
    );
  }
}
