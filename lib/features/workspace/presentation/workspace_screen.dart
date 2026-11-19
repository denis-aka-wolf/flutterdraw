import 'package:flutter/material.dart';

import '../../canvas/presentation/canvas_viewport.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _WorkspaceHeader(),
            Expanded(
              child: Row(
                children: [
                  const _ToolRail(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: const CanvasViewport(),
                      ),
                    ),
                  ),
                  const _InspectorPanel(),
                ],
              ),
            ),
            const _StatusBar(),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withOpacity(0.4)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.gesture_rounded, color: colors.primary),
          const SizedBox(width: 10),
          Text(
            'FlutterDraw',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 24),
          Text('Без названия'),
          const Spacer(),
          IconButton(
            tooltip: 'Отменить',
            onPressed: null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Повторить',
            onPressed: null,
            icon: const Icon(Icons.redo_rounded),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: null,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Экспорт'),
          ),
        ],
      ),
    );
  }
}

class _ToolRail extends StatelessWidget {
  const _ToolRail();

  static const tools = <(IconData, String)>[
    (Icons.ads_click, 'Выбор'),
    (Icons.pan_tool_alt_outlined, 'Рука'),
    (Icons.rectangle_outlined, 'Прямоугольник'),
    (Icons.circle_outlined, 'Эллипс'),
    (Icons.diamond_outlined, 'Ромб'),
    (Icons.timeline, 'Линия'),
    (Icons.arrow_right_alt, 'Стрелка'),
    (Icons.gesture, 'Рисование'),
    (Icons.title, 'Текст'),
    (Icons.image_outlined, 'Изображение'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final tool in tools)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: IconButton(
                tooltip: tool.$2,
                onPressed: null,
                icon: Icon(tool.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Свойства', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(
            'Выберите объект на холсте, чтобы изменить его свойства.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Text('Готово', style: Theme.of(context).textTheme.labelSmall),
          const Spacer(),
          Text('100%', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
