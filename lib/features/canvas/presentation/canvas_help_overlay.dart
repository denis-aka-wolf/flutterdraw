import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Компактная справка по управлению холстом с сохранением размера.
class CanvasHelpOverlay extends StatefulWidget {
  const CanvasHelpOverlay({super.key});

  @override
  State<CanvasHelpOverlay> createState() => _CanvasHelpOverlayState();
}

class _CanvasHelpOverlayState extends State<CanvasHelpOverlay> {
  static const _widthKey = 'canvas_help_overlay_width';
  static const _heightKey = 'canvas_help_overlay_height';
  static const double _defaultWidth = 260;
  static const double _defaultHeight = 360;
  static const double _minWidth = 230;
  static const double _minHeight = 250;
  static const double _maxWidth = 420;
  static const double _maxHeight = 620;

  bool _expanded = false;
  bool _settingsLoaded = false;
  double _panelWidth = _defaultWidth;
  double _panelHeight = _defaultHeight;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _panelWidth = (prefs.getDouble(_widthKey) ?? _defaultWidth)
          .clamp(_minWidth, _maxWidth)
          .toDouble();
      _panelHeight = (prefs.getDouble(_heightKey) ?? _defaultHeight)
          .clamp(_minHeight, _maxHeight)
          .toDouble();
      _settingsLoaded = true;
    });
  }

  Future<void> _saveSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_widthKey, _panelWidth);
    await prefs.setDouble(_heightKey, _panelHeight);
  }

  void _resize(DragUpdateDetails details) {
    if (!_settingsLoaded) return;
    setState(() {
      // Ручка слева снизу: правый верхний угол панели остаётся на месте.
      _panelWidth = (_panelWidth - details.delta.dx)
          .clamp(_minWidth, _maxWidth)
          .toDouble();
      _panelHeight = (_panelHeight + details.delta.dy)
          .clamp(_minHeight, _maxHeight)
          .toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topRight,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topRight,
        child: Material(
          color: colors.surface.withValues(alpha: 0.88),
          elevation: 5,
          shadowColor: Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.65)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _expanded
                ? SizedBox(
                    width: _panelWidth,
                    height: _panelHeight,
                    child: _buildExpanded(context),
                  )
                : _buildCollapsed(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => setState(() => _expanded = true),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline_rounded, size: 16, color: colors.primary),
            const SizedBox(width: 7),
            Text(
              'Подсказка  >>>',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 17, color: colors.primary),
              const SizedBox(width: 7),
              Text(
                'Подсказки',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (!_settingsLoaded)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, 'Инструменты'),
                  _hintRow(context, 'Выбор', 'Выделение и перемещение'),
                  _hintRow(context, 'Рука', 'Перемещение холста'),
                  _hintRow(context, 'Прямоугольник', 'Нарисовать прямоугольник'),
                  _hintRow(context, 'Эллипс / Ромб', 'Нарисовать фигуру'),
                  _hintRow(context, 'Линия / Стрелка', 'Соединить точки'),
                  _hintRow(context, 'От руки', 'Рисовать свободно'),
                  const SizedBox(height: 7),
                  _sectionTitle(context, 'Действия мышью'),
                  _hintRow(context, 'Колесо', 'Масштаб вокруг курсора'),
                  _hintRow(context, 'Пробел + drag', 'Переместить холст'),
                  _hintRow(context, 'Средняя кнопка', 'Переместить холст'),
                  _hintRow(context, 'Shift + клик', 'Добавить к выделению'),
                  _hintRow(context, 'Рамка на пустом месте', 'Выбрать несколько'),
                  const SizedBox(height: 7),
                  _sectionTitle(context, 'Сочетания клавиш'),
                  _hintRow(context, 'Ctrl/Cmd + Z', 'Отменить действие'),
                  _hintRow(context, 'Ctrl/Cmd + Shift + Z', 'Повторить действие'),
                  _hintRow(context, 'Ctrl/Cmd + Y', 'Повторить действие'),
                  _hintRow(context, 'Ctrl/Cmd + C', 'Копировать'),
                  _hintRow(context, 'Ctrl/Cmd + V', 'Вставить'),
                  _hintRow(context, 'Ctrl/Cmd + D', 'Дублировать'),
                  _hintRow(context, 'Ctrl/Cmd + ]', 'На передний план'),
                  _hintRow(context, 'Ctrl/Cmd + [', 'На задний план'),
                  _hintRow(context, 'Delete', 'Удалить выделенное'),
                  _hintRow(context, 'Escape', 'Сбросить выделение'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Tooltip(
                message: 'Потяните за угол, чтобы изменить размер',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: _settingsLoaded ? _resize : null,
                  onPanEnd: (_) => _saveSize(),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      Icons.open_in_full_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _expanded = false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: colors.outlineVariant),
                    ),
                    child: const Text('Свернуть'),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_panelWidth.round()}×${_panelHeight.round()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _hintRow(BuildContext context, String action, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              action,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 6,
            child: Text(
              description,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
