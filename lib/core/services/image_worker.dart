/// Shares one CPU slot between import inspection, previews and conversion in
/// the calling isolate. The worker itself still runs off the Flutter UI thread.
abstract final class ImageWorker {
  static Future<void> _tail = Future<void>.value();
  static Future<T> run<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }
}
