import '../core/image_engine.dart';
import 'editor_settings.dart';

extension EditorSerialization on EditorSettings {
  Map<String, dynamic> toJson() => {
    'keepFormat': keepFormat,
    'resizeEnabled': resizeEnabled,
    'keepRatio': keepRatio,
    'preventUpscale': preventUpscale,
    'flipHorizontal': flipHorizontal,
    'flipVertical': flipVertical,
    'stripMetadata': stripMetadata,
    'renameEnabled': renameEnabled,
    'sequence': sequence,
    'quality': quality,
    'pngCompression': pngCompression,
    'backgroundRgb': backgroundRgb,
    'width': width,
    'height': height,
    'percent': percent,
    'edge': edge,
    'quarterTurns': quarterTurns,
    'start': start,
    'digits': digits,
    'prefix': prefix,
    'suffix': suffix,
    'format': format.name,
    'resizeMode': resizeMode.name,
    'crop': crop == null
        ? null
        : [crop!.left, crop!.top, crop!.width, crop!.height],
  };
  void apply(EditorSettings s) {
    keepFormat = s.keepFormat;
    resizeEnabled = s.resizeEnabled;
    keepRatio = s.keepRatio;
    preventUpscale = s.preventUpscale;
    flipHorizontal = s.flipHorizontal;
    flipVertical = s.flipVertical;
    stripMetadata = s.stripMetadata;
    renameEnabled = s.renameEnabled;
    sequence = s.sequence;
    quality = s.quality;
    pngCompression = s.pngCompression;
    backgroundRgb = s.backgroundRgb;
    width = s.width;
    height = s.height;
    percent = s.percent;
    edge = s.edge;
    quarterTurns = s.quarterTurns;
    start = s.start;
    digits = s.digits;
    prefix = s.prefix;
    suffix = s.suffix;
    format = s.format;
    resizeMode = s.resizeMode;
    crop = s.crop;
  }
}

EditorSettings editorFromJson(Map<String, dynamic> m) {
  final s = EditorSettings();
  if (m['keepFormat'] is bool) s.keepFormat = m['keepFormat'] as bool;
  if (m['resizeEnabled'] is bool) s.resizeEnabled = m['resizeEnabled'] as bool;
  if (m['keepRatio'] is bool) s.keepRatio = m['keepRatio'] as bool;
  if (m['preventUpscale'] is bool) {
    s.preventUpscale = m['preventUpscale'] as bool;
  }
  if (m['flipHorizontal'] is bool) {
    s.flipHorizontal = m['flipHorizontal'] as bool;
  }
  if (m['flipVertical'] is bool) s.flipVertical = m['flipVertical'] as bool;
  if (m['stripMetadata'] is bool) s.stripMetadata = m['stripMetadata'] as bool;
  if (m['renameEnabled'] is bool) s.renameEnabled = m['renameEnabled'] as bool;
  if (m['sequence'] is bool) s.sequence = m['sequence'] as bool;
  if (m['quality'] is int) s.quality = (m['quality'] as int).clamp(1, 100);
  if (m['pngCompression'] is int) {
    s.pngCompression = (m['pngCompression'] as int).clamp(0, 9);
  }
  if (m['backgroundRgb'] is int) {
    s.backgroundRgb = (m['backgroundRgb'] as int).clamp(0, 16777215);
  }
  if (m['width'] is int) s.width = (m['width'] as int).clamp(1, 16384);
  if (m['height'] is int) s.height = (m['height'] as int).clamp(1, 16384);
  if (m['percent'] is int) s.percent = (m['percent'] as int).clamp(1, 1000);
  if (m['edge'] is int) s.edge = (m['edge'] as int).clamp(1, 16384);
  if (m['quarterTurns'] is int) {
    s.quarterTurns = (m['quarterTurns'] as int).clamp(-10000, 10000);
  }
  if (m['start'] is int) s.start = (m['start'] as int).clamp(0, 99999999);
  if (m['digits'] is int) s.digits = (m['digits'] as int).clamp(1, 8);
  for (final f in [RasterFormat.jpeg, RasterFormat.png, RasterFormat.webp]) {
    if (f.name == m['format']) s.format = f;
  }
  for (final r in ResizeMode.values) {
    if (r.name == m['resizeMode']) s.resizeMode = r;
  }
  if (m['prefix'] is String) {
    s.prefix = (m['prefix'] as String).substring(
      0,
      (m['prefix'] as String).length.clamp(0, 80),
    );
  }
  if (m['suffix'] is String) {
    s.suffix = (m['suffix'] as String).substring(
      0,
      (m['suffix'] as String).length.clamp(0, 80),
    );
  }
  final c = m['crop'];
  if (c is List && c.length == 4 && c.every((v) => v is num)) {
    try {
      final r = CropRegion(
        (c[0] as num).toDouble(),
        (c[1] as num).toDouble(),
        (c[2] as num).toDouble(),
        (c[3] as num).toDouble(),
      );
      r.validate();
      s.crop = r;
    } catch (_) {}
  }
  return s;
}
