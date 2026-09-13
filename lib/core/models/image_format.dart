enum RasterFormat {
  jpeg('JPG', 'jpg'),
  png('PNG', 'png'),
  webp('WebP', 'webp'),
  bmp('BMP', 'bmp'),
  gif('GIF', 'gif'),
  tiff('TIFF', 'tiff'),
  tga('TGA', 'tga'),
  ico('ICO', 'ico');

  const RasterFormat(this.label, this.extension);
  final String label;
  final String extension;
}

/// Only formats implemented by our encoder are exposed as output options.
const supportedOutputFormats = {
  RasterFormat.jpeg,
  RasterFormat.png,
  RasterFormat.webp,
};
