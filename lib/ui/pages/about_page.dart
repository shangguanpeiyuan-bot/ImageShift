import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/brand_mark.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.version});
  final String version;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 70)),
      const SizedBox(height: 22),
      Text('ImageShift', style: Theme.of(context).textTheme.headlineLarge),
      Text(version.isEmpty ? '正在读取版本…' : '版本 $version'),
      const SizedBox(height: 12),
      const Text('快速、安全的本地图片处理工具'),
      const SizedBox(height: 26),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '你的图片，留在你的设备上。',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10),
              Text('所有图片处理均在本地完成，不会上传至服务器。不需要账户。所有变换另存新文件，永不覆盖原图。'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text('格式与限制', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      const Text(
        '输入：JPG、PNG、WebP、BMP、静态 GIF、单页 TIFF、未压缩真彩 TGA、内嵌 PNG 的单图像 ICO。输出：JPG、PNG、无损 WebP。动画和多页图片会被拒绝，避免丢失内容。',
      ),
      const SizedBox(height: 10),
      const Text(
        '当前单文件上限 128 MiB / 2400 万像素 / 单边 16384 px，每批最多 500 项。处理任务逐张执行。预览可能缩小，导出按真实参数执行。',
      ),
      const SizedBox(height: 24),
      Text('开源与许可', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      const Text('项目许可证尚未选定；依赖许可证不代表项目自身的授权。'),
      const SelectableText(
        'https://github.com/shangguanpeiyuan-bot/ImageShift',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(
                text: 'https://github.com/shangguanpeiyuan-bot/ImageShift',
              ),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('仓库链接已复制')));
            }
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('复制仓库链接'),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'ImageShift',
            applicationVersion: version,
          ),
          child: const Text('查看开源依赖许可'),
        ),
      ),
    ],
  );
}
