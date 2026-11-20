import 'package:flutter/material.dart';

import '../../../application/canvas/canvas_editor_controller.dart';
import '../../../application/canvas/canvas_tool.dart';
import '../../canvas/presentation/canvas_viewport.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final CanvasEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CanvasEditorController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                  _ToolRail(controller: _controller),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CanvasViewport(controller: _controller),
                      ),
                    ),
                  ),
                  const _InspectorPanel(),
                ],
              ),
            ),
            _StatusBar(controller: _controller),
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
          const Text('Без названия'),
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
  const _ToolRail({required this.controller});

  final CanvasEditorController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 64,
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Column(
            children: [
              _ToolButton(
                controller: controller,
                tool: CanvasTool.select,
                icon: Icons.ads_click,
                tooltip: 'Выбор',
                enabled: true,
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.hand,
                icon: Icons.pan_tool_alt_outlined,
                tooltip: 'Рука',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.rectangle,
                icon: Icons.rectangle_outlined,
                tooltip: 'Прямоугольник',
              ),
              for (final item in const <(IconData, String)>[
                (Icons.circle_outlined, 'Эллипс'),
                (Icons.diamond_outlined, 'Ромб'),
                (Icons.timeline, 'Линия'),
                (Icons.arrow_right_alt, 'Стрелка'),
                (Icons.gesture, 'Рисование'),
                (Icons.title, 'Текст'),
                (Icons.image_outlined, 'Изображение'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: IconButton(
                    tooltip: item.$2,
                    onPressed: null,
                    icon: Icon(item.$1),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.controller,
    required this.tool,
    required this.icon,
    required this.tooltip,
    this.enabled = true,
  });

  final CanvasEditorController controller;
  final CanvasTool tool;
  final IconData icon;
  final String tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selected = controller.activeTool == tool;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? () => controller.setActiveTool(tool) : null,
        style: IconButton.styleFrom(
          backgroundColor: selected ? colors.secondaryContainer : null,
          foregroundColor:
              selected ? colors.onSecondaryContainer : colors.onSurface,
        ),
        icon: Icon(icon),
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
  const _StatusBar({required this.controller});

  final CanvasEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final count = controller.document.rectangles.length;
          return Row(
            children: [
              Text('Готово', style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              Text(
                '$count объектов',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
