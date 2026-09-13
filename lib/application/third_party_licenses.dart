import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Expose bundled notices offline, including native libraries not in pub's
/// generated license collection. JSON provenance manifests are not licenses.
Stream<LicenseEntry> bundledLicenses(AssetBundle bundle) async* {
  yield LicenseEntryWithLineBreaks([
    'ImageShift',
  ], await bundle.loadString('LICENSE'));
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final notices =
      manifest
          .listAssets()
          .where(
            (path) =>
                path.startsWith('docs/third_party/') &&
                (path.endsWith('.txt') || path.endsWith('.md')),
          )
          .toList()
        ..sort();
  for (final path in notices) {
    yield LicenseEntryWithLineBreaks([
      path.substring('docs/third_party/'.length),
    ], await bundle.loadString(path));
  }
}
