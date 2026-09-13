import 'package:flutter/material.dart';

import '../../core/image_engine.dart';

String statusLabel(TaskStatus status) => switch (status) {
  TaskStatus.pending => '等待',
  TaskStatus.processing => '处理中',
  TaskStatus.succeeded => '成功',
  TaskStatus.failed => '失败',
  TaskStatus.cancelled => '已取消',
};

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final TaskStatus status;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      TaskStatus.failed => scheme.error,
      TaskStatus.succeeded => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (status) {
              TaskStatus.pending => Icons.schedule_rounded,
              TaskStatus.processing => Icons.autorenew_rounded,
              TaskStatus.succeeded => Icons.check_circle_outline,
              TaskStatus.failed => Icons.error_outline,
              TaskStatus.cancelled => Icons.block_rounded,
            },
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            statusLabel(status),
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}
