import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../infrastructure/files/document_file_writer.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../infrastructure/serialization/draw_document_codec.dart';
import '../../../infrastructure/export/document_export.dart';
import '../../../infrastructure/serialization/excalidraw_codec.dart';

import '../../../application/canvas/canvas_editor_controller.dart';
import '../../../application/canvas/canvas_tool.dart';
import '../../../domain/elements/drawing_element.dart';
import '../../canvas/presentation/canvas_help_overlay.dart';
import '../../canvas/presentation/canvas_viewport.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final CanvasEditorController _controller;
  static const _autosaveKey = 'flutterdraw_autosave_v1';
  final _codec = const DrawDocumentCodec();
  final _excalidrawCodec = const ExcalidrawCodec();
  Timer? _autosaveTimer;
  String _documentTitle = 'Без названия';
  String? _documentPath;
  bool _restoringSession = false;
  String? _lastAutosavedContent;
  String? _lastAutosavedTitle;
  String? _savedContent;
  bool _isSaving = false;
  String _saveStatus = 'Сохранено';

  @override
  void initState() {
    super.initState();
    _controller = CanvasEditorController();
    _savedContent = _codec.encode(_controller.document, pretty: false);
    _controller.addListener(_onDocumentChanged);
    _restoreSession();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _controller.removeListener(_onDocumentChanged);
    _controller.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges =>
      _savedContent != _codec.encode(_controller.document, pretty: false);

  void _onDocumentChanged() {
    if (_restoringSession) {
      return;
    }
    if (mounted) {
      setState(() => _saveStatus = _hasUnsavedChanges ? 'Есть изменения' : 'Сохранено');
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 700), _writeAutosave);
  }

  Future<void> _writeAutosave() async {
    final content = _codec.encode(_controller.document, pretty: false);
    if (content == _lastAutosavedContent &&
        _documentTitle == _lastAutosavedTitle) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autosaveKey, jsonEncode({
      'title': _documentTitle,
      'document': jsonDecode(content),
    }));
    _lastAutosavedContent = content;
    _lastAutosavedTitle = _documentTitle;
    if (mounted) {
      setState(() => _saveStatus =
          _hasUnsavedChanges ? 'Автосохранено' : 'Сохранено');
    }
  }

  Future<void> _restoreSession() async {
    _restoringSession = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_autosaveKey);
      if (raw == null) {
      return;
    }
      final session = jsonDecode(raw);
      if (session is! Map<String, dynamic> ||
          session['document'] is! Map<String, dynamic>) return;
      final document = _codec.decode(jsonEncode(session['document']));
      if (!mounted) {
        return;
      }
      setState(() {
        _documentTitle = session['title'] is String
            ? session['title'] as String
            : 'Без названия';
      });
      _controller.loadDocument(document);
      _documentPath = null;
      _lastAutosavedContent = _codec.encode(document, pretty: false);
      _lastAutosavedTitle = _documentTitle;
      _savedContent = null;
      if (mounted) setState(() => _saveStatus = 'Восстановлено');
    } catch (_) {
      // A damaged recovery snapshot must not prevent the editor from opening.
    } finally {
      _restoringSession = false;
    }
  }

  Future<void> _newDocument() async {
    if (!await _confirmDiscardChanges()) return;
    _autosaveTimer?.cancel();
    _controller.newDocument();
    _documentPath = null;
    _savedContent = _codec.encode(_controller.document, pretty: false);
    setState(() {
      _documentTitle = 'Без названия';
      _saveStatus = 'Сохранено';
    });
    _lastAutosavedContent = null;
    _lastAutosavedTitle = null;
    _onDocumentChanged();
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text(
          'В документе есть изменения. Продолжить без сохранения?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  KeyEventResult _handleWorkspaceKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final primaryContext = FocusManager.instance.primaryFocus?.context;
    if (primaryContext?.widget is EditableText) return KeyEventResult.ignored;
    final isCommand = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!isCommand) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyN:
        _newDocument();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyO:
        _openDocument();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyS:
        if (HardwareKeyboard.instance.isShiftPressed) {
          _saveDocumentAs();
        } else {
          _saveDocument();
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  Future<void> _openDocument() async {
    if (!await _confirmDiscardChanges()) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['flutterdraw', 'excalidraw', 'json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
      return;
    }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('Не удалось прочитать содержимое файла.');
      }
      final source = utf8.decode(bytes);
      final decoded = jsonDecode(source);
      final isExcalidraw = decoded is Map && decoded['type'] == 'excalidraw';
      final document = isExcalidraw
          ? _excalidrawCodec.decode(source)
          : _codec.decode(source);
      _controller.loadDocument(document);
      _documentPath = kIsWeb || isExcalidraw ? null : file.path;
      _savedContent = _codec.encode(document, pretty: false);
      setState(() {
        _documentTitle = isExcalidraw
            ? file.name.replaceFirst(
                RegExp(r'\.(excalidraw|json)$', caseSensitive: false),
                '',
              )
            : file.name;
        _saveStatus = 'Сохранено';
      });
      _lastAutosavedContent = null;
      _lastAutosavedTitle = null;
      _onDocumentChanged();
    } catch (error) {
      if (!mounted) {
      return;
    }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть документ: $error')),
      );
    }
  }

  Future<void> _saveDocument() async {
    if (_documentPath == null || kIsWeb) {
      await _saveDocumentAs();
      return;
    }
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveStatus = 'Сохранение…';
    });
    try {
      final content = _codec.encode(_controller.document);
      final bytes = Uint8List.fromList(utf8.encode(content));
      await writeDocumentFile(_documentPath!, bytes);
      _savedContent = _codec.encode(_controller.document, pretty: false);
      final fileName = _documentPath!.split(RegExp(r'[/\\\\]')).last;
      if (mounted) {
        setState(() => _saveStatus = 'Сохранено');
      }
      _lastAutosavedContent = null;
      _lastAutosavedTitle = null;
      await _writeAutosave();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Документ сохранён: $fileName')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить документ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = _hasUnsavedChanges ? 'Есть изменения' : 'Сохранено';
        });
      }
    }
  }

  Future<void> _exportPng() async {
    try {
      final bytes = await DocumentExport.png(_controller.document);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Экспортировать холст в PNG',
        fileName: 'FlutterDraw.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
        bytes: bytes,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PNG экспортирован: ${path.split(RegExp(r'[/\\\\]')).last}')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать PNG: $error')),
      );
    }
  }

  Future<void> _exportSvg() async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(DocumentExport.svg(_controller.document)));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Экспортировать холст в SVG',
        fileName: 'FlutterDraw.svg',
        type: FileType.custom,
        allowedExtensions: ['svg'],
        bytes: bytes,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SVG экспортирован: ${path.split(RegExp(r'[/\\\\]')).last}')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать SVG: $error')),
      );
    }
  }

  Future<void> _exportExcalidraw() async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(_excalidrawCodec.encode(_controller.document)));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Экспортировать в Excalidraw',
        fileName: 'FlutterDraw.excalidraw',
        type: FileType.custom,
        allowedExtensions: ['excalidraw'],
        bytes: bytes,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excalidraw экспортирован: ${path.split(RegExp(r'[/\\\\]')).last}')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать Excalidraw: $error')),
      );
    }
  }

  Future<void> _saveDocumentAs() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveStatus = 'Сохранение…';
    });
    try {
      final content = _codec.encode(_controller.document);
      final bytes = Uint8List.fromList(utf8.encode(content));
      final suggestedName = _documentTitle == 'Без названия'
          ? 'Без названия.flutterdraw'
          : (_documentTitle.endsWith('.flutterdraw')
              ? _documentTitle
              : '$_documentTitle.flutterdraw');
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить документ FlutterDraw',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['flutterdraw'],
        bytes: bytes,
      );
      if (savedPath == null) return;
      final fileName = savedPath.split(RegExp(r'[/\\\\]')).last;
      if (!kIsWeb) _documentPath = savedPath;
      _savedContent = _codec.encode(_controller.document, pretty: false);
      if (mounted) {
        setState(() {
          _documentTitle = fileName;
          _saveStatus = 'Сохранено';
        });
      }
      _lastAutosavedContent = null;
      _lastAutosavedTitle = null;
      await _writeAutosave();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Документ сохранён: $fileName')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить документ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = _hasUnsavedChanges ? 'Есть изменения' : 'Сохранено';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleWorkspaceKeyEvent,
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _WorkspaceHeader(
              controller: _controller,
              title: _documentTitle,
              onNew: _newDocument,
              onOpen: _openDocument,
              onSave: _saveDocument,
              onSaveAs: _saveDocumentAs,
              onExportPng: _exportPng,
              onExportSvg: _exportSvg,
              onExportExcalidraw: _exportExcalidraw,
              saveStatus: _saveStatus,
            ),
            Expanded(
              child: Row(
                children: [
                  _ToolRail(controller: _controller),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CanvasViewport(controller: _controller),
                            const Positioned(
                              top: 10,
                              right: 10,
                              child: CanvasHelpOverlay(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 272, child: Column(children: [
                    Expanded(child: _InspectorPanel(controller: _controller)),
                    SizedBox(height: 230, child: _LayersPanel(controller: _controller)),
                  ])),
                ],
              ),
            ),
            _StatusBar(controller: _controller),
          ],
        ),
      ),
    ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.controller,
    required this.title,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onExportPng,
    required this.onExportSvg,
    required this.onExportExcalidraw,
    required this.saveStatus,
  });

  final CanvasEditorController controller;
  final String title;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onExportPng;
  final VoidCallback onExportSvg;
  final VoidCallback onExportExcalidraw;
  final String saveStatus;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
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
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          Text(saveStatus, style: Theme.of(context).textTheme.labelSmall),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Файл',
            onSelected: (value) {
              switch (value) {
                case 'new':
                  onNew();
                  break;
                case 'open':
                  onOpen();
                  break;
                case 'save':
                  onSave();
                  break;
                case 'saveAs':
                  onSaveAs();
                  break;
                case 'exportPng':
                  onExportPng();
                  break;
                case 'exportSvg':
                  onExportSvg();
                  break;
                case 'exportExcalidraw':
                  onExportExcalidraw();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'new',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.note_add_outlined),
                  title: Text('Новый'),
                  trailing: Text('Ctrl+N'),
                ),
              ),
              PopupMenuItem(
                value: 'open',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.folder_open_outlined),
                  title: Text('Открыть…'),
                  trailing: Text('Ctrl+O'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'save',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.save_outlined),
                  title: Text('Сохранить'),
                  trailing: Text('Ctrl+S'),
                ),
              ),
              PopupMenuItem(
                value: 'saveAs',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.save_as_outlined),
                  title: Text('Сохранить как…'),
                  trailing: Text('Ctrl+Shift+S'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'exportPng',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.image_outlined),
                  title: Text('Экспорт PNG…'),
                ),
              ),
              PopupMenuItem(
                value: 'exportSvg',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.code),
                  title: Text('Экспорт SVG…'),
                ),
              ),
              PopupMenuItem(
                value: 'exportExcalidraw',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.import_export),
                  title: Text('Экспорт Excalidraw…'),
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu),
                  SizedBox(width: 6),
                  Text('Файл'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Дублировать (Ctrl+D)',
            onPressed: controller.duplicateSelection,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'На передний план (Ctrl+])',
            onPressed: controller.bringSelectionToFront,
            icon: const Icon(Icons.flip_to_front),
          ),
          IconButton(
            tooltip: 'На задний план (Ctrl+[)',
            onPressed: controller.sendSelectionToBack,
            icon: const Icon(Icons.flip_to_back),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => IconButton(
              tooltip: 'Отменить (Ctrl+Z)',
              onPressed: controller.canUndo ? controller.undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => IconButton(
              tooltip: 'Повторить (Ctrl+Shift+Z)',
              onPressed: controller.canRedo ? controller.redo : null,
              icon: const Icon(Icons.redo_rounded),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Новый документ', onPressed: onNew,
            icon: const Icon(Icons.note_add_outlined)),
          IconButton(tooltip: 'Открыть документ', onPressed: onOpen,
            icon: const Icon(Icons.folder_open_outlined)),
          FilledButton.tonalIcon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Сохранить'),
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
              _ToolButton(
                controller: controller,
                tool: CanvasTool.ellipse,
                icon: Icons.circle_outlined,
                tooltip: 'Эллипс',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.diamond,
                icon: Icons.diamond_outlined,
                tooltip: 'Ромб',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.line,
                icon: Icons.timeline,
                tooltip: 'Линия',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.arrow,
                icon: Icons.arrow_right_alt,
                tooltip: 'Стрелка',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.text,
                icon: Icons.text_fields,
                tooltip: 'Текст',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.freehand,
                icon: Icons.gesture,
                tooltip: 'Рисование от руки',
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
  const _InspectorPanel({required this.controller});
  final CanvasEditorController controller;

  static const _palette = <int>[
    0xFF252525, 0xFF6B7280, 0xFFDC2626, 0xFFEA580C,
    0xFFD97706, 0xFF16A34A, 0xFF0891B2, 0xFF2563EB,
    0xFF7C3AED, 0xFFDB2777, 0xFFFFFFFF,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final selected = controller.selectedElements;
          if (selected.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Свойства', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('Выберите один или несколько объектов на холсте.',
                  style: Theme.of(context).textTheme.bodySmall),
              ],
            );
          }
          final element = selected.first;
          final isText = selected.length == 1 && element.type == DrawingElementType.text;
          final hasFill = selected.any((e) =>
              e.type == DrawingElementType.rectangle ||
              e.type == DrawingElementType.ellipse ||
              e.type == DrawingElementType.diamond);
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Свойства', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                _section(context, element.type == DrawingElementType.text ? 'Цвет текста' : 'Цвет обводки'),
                _colorChoices(
                  selectedColor: element.strokeColor,
                  onSelected: (color) => controller.updateSelectedProperties(strokeColor: color),
                ),
                const SizedBox(height: 14),
                if (hasFill) ...[
                  _section(context, 'Заливка'),
                  _colorChoices(
                    selectedColor: element.fillColor,
                    allowNone: true,
                    onSelected: (color) => controller.updateSelectedProperties(fillColor: color),
                  ),
                  const SizedBox(height: 14),
                ],
                if (element.type != DrawingElementType.text) ...[
                  _section(context, 'Толщина линии: ${element.strokeWidth.toStringAsFixed(1)}'),
                  Slider(
                    min: 0.5, max: 12, divisions: 23,
                    value: element.strokeWidth.clamp(0.5, 12).toDouble(),
                    onChanged: (value) => controller.updateSelectedProperties(strokeWidth: value),
                  ),
                  const SizedBox(height: 8),
                ],
                _section(context, 'Непрозрачность: ${(element.opacity * 100).round()}%'),
                Slider(
                  min: 0.05, max: 1, divisions: 19,
                  value: element.opacity.clamp(0.05, 1).toDouble(),
                  onChanged: (value) => controller.updateSelectedProperties(opacity: value),
                ),
                if (isText) ...[
                  const Divider(height: 26),
                  _section(context, 'Содержимое'),
                  TextFormField(
                    key: ValueKey('text-${element.id}'),
                    initialValue: element.text,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(), isDense: true,
                    ),
                    onChanged: controller.updateSelectedText,
                  ),
                  const SizedBox(height: 14),
                  _section(context, 'Шрифт'),
                  DropdownButtonFormField<String>(
                    initialValue: const ['Roboto', 'Arial', 'Georgia', 'Courier New', 'Times New Roman'].contains(element.fontFamily) ? element.fontFamily : 'Roboto',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(), isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                      DropdownMenuItem(value: 'Arial', child: Text('Arial')),
                      DropdownMenuItem(value: 'Georgia', child: Text('Georgia')),
                      DropdownMenuItem(value: 'Courier New', child: Text('Courier New')),
                      DropdownMenuItem(value: 'Times New Roman', child: Text('Times New Roman')),
                    ],
                    onChanged: (value) {
                      if (value != null) controller.updateSelectedProperties(fontFamily: value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _section(context, 'Размер шрифта: ${element.fontSize.round()}'),
                  Slider(
                    min: 10, max: 96, divisions: 43,
                    value: element.fontSize.clamp(10, 96).toDouble(),
                    onChanged: controller.setSelectedTextFontSize,
                  ),
                  _section(context, 'Выравнивание'),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left)),
                      ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center)),
                      ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right)),
                    ],
                    selected: {const ['left', 'center', 'right'].contains(element.textAlign) ? element.textAlign : 'left'},
                    onSelectionChanged: (values) =>
                      controller.updateSelectedProperties(textAlign: values.first),
                  ),
                  const SizedBox(height: 12),
                  _section(context, 'Размер текстового блока'),
                  _dimensionField(context, 'Ширина', element.width,
                    (value) => controller.setSelectedTextBlockSize(width: value)),
                  const SizedBox(height: 8),
                  _dimensionField(context, 'Высота', element.height,
                    (value) => controller.setSelectedTextBlockSize(height: value)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _colorChoices({
    required int selectedColor,
    required ValueChanged<int> onSelected,
    bool allowNone = false,
  }) {
    return Wrap(
      spacing: 7, runSpacing: 7,
      children: [
        if (allowNone)
          InkWell(
            onTap: () => onSelected(0x00000000),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selectedColor == 0 ? Colors.blue : Colors.grey,
                  width: selectedColor == 0 ? 2.5 : 1,
                ),
              ),
              child: const Icon(Icons.block, size: 15),
            ),
          ),
        for (final color in _palette)
          InkWell(
            onTap: () => onSelected(color),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: Color(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selectedColor == color ? Colors.blue : Colors.black26,
                  width: selectedColor == color ? 2.5 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _dimensionField(BuildContext context, String label, double value,
      ValueChanged<double> onSubmitted) {
    return Row(
      children: [
        SizedBox(width: 58, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Expanded(
          child: TextFormField(
            key: ValueKey('$label-${value.round()}'),
            initialValue: value.round().toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              suffixText: 'px', isDense: true, border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (raw) {
              final parsed = double.tryParse(raw);
              if (parsed != null && parsed.isFinite) onSubmitted(parsed);
            },
          ),
        ),
      ],
    );
  }
}

class _LayersPanel extends StatelessWidget {
  const _LayersPanel({required this.controller});
  final CanvasEditorController controller;

  String _label(DrawingElement element) {
    if (element.type == DrawingElementType.text && element.text.trim().isNotEmpty) {
      final value = element.text.replaceAll('\n', ' ').trim();
      return value.length > 22 ? '${value.substring(0, 22)}…' : value;
    }
    return switch (element.type) {
      DrawingElementType.rectangle => 'Прямоугольник',
      DrawingElementType.ellipse => 'Эллипс',
      DrawingElementType.diamond => 'Ромб',
      DrawingElementType.line => 'Линия',
      DrawingElementType.arrow => 'Стрелка',
      DrawingElementType.freehand => 'Рисунок от руки',
      DrawingElementType.text => 'Текст',
    };
  }

  IconData _icon(DrawingElementType type) => switch (type) {
    DrawingElementType.rectangle => Icons.rectangle_outlined,
    DrawingElementType.ellipse => Icons.circle_outlined,
    DrawingElementType.diamond => Icons.diamond_outlined,
    DrawingElementType.line => Icons.timeline,
    DrawingElementType.arrow => Icons.arrow_right_alt,
    DrawingElementType.freehand => Icons.gesture,
    DrawingElementType.text => Icons.text_fields,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final layers = controller.document.elements.reversed.toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.layers_outlined, size: 18),
              const SizedBox(width: 7),
              Expanded(child: Text('Слои', style: Theme.of(context).textTheme.titleSmall)),
              Text('${layers.length}', style: Theme.of(context).textTheme.labelSmall),
            ]),
            SwitchListTile(dense: true, contentPadding: EdgeInsets.zero,
              title: const Text('Привязка к сетке'), value: controller.snapToGrid,
              onChanged: controller.setSnapToGrid),
            SwitchListTile(dense: true, contentPadding: EdgeInsets.zero,
              title: const Text('Умные направляющие'), value: controller.snapToGuides,
              onChanged: controller.setSnapToGuides),
            const Divider(height: 8),
            Expanded(child: layers.isEmpty
              ? Center(child: Text('Нет объектов', style: Theme.of(context).textTheme.bodySmall))
              : ReorderableListView.builder(
                  buildDefaultDragHandles: true,
                  itemCount: layers.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final reordered = [...layers];
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    controller.reorderLayers(reordered.map((e) => e.id).toList());
                  },
                  itemBuilder: (context, index) {
                    final element = layers[index];
                    final selected = controller.selectedElementIds.contains(element.id);
                    final groupId = element.extraData['flutterdrawGroupId'];
                    return ListTile(
                      key: ValueKey(element.id), dense: true,
                      visualDensity: VisualDensity.compact,
                      selected: selected, selectedTileColor: colors.secondaryContainer,
                      leading: Icon(_icon(element.type), size: 17),
                      title: Text(_label(element), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: groupId is String ? const Text('Группа') : null,
                      onTap: () => controller.selectElementById(element.id),
                    );
                  },
                )),
          ]);
        },
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
          final count = controller.document.elements.length;
          final selectedCount = controller.selectedElementIds.length;
          return Row(
            children: [
              Text(
                selectedCount > 0 ? 'Выбрано: $selectedCount' : 'Готово',
                style: Theme.of(context).textTheme.labelSmall,
              ),
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
, caseSensitive: false), '')
            : file.name;
        _saveStatus = 'Сохранено';
      });
      _lastAutosavedContent = null;
      _lastAutosavedTitle = null;
      _onDocumentChanged();
    } catch (error) {
      if (!mounted) {
      return;
    }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть документ: $error')),
      );
    }
  }

  Future<void> _saveDocument() async {
    if (_documentPath == null || kIsWeb) {
      await _saveDocumentAs();
      return;
    }
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveStatus = 'Сохранение…';
    });
    try {
      final content = _codec.encode(_controller.document);
      final bytes = Uint8List.fromList(utf8.encode(content));
      await writeDocumentFile(_documentPath!, bytes);
      _savedContent = _codec.encode(_controller.document, pretty: false);
      final fileName = _documentPath!.split(RegExp(r'[/\\\\]')).last;
      if (mounted) {
        setState(() => _saveStatus = 'Сохранено');
      }
      _lastAutosavedContent = null;
      _lastAutosavedTitle = null;
      await _writeAutosave();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Документ сохранён: $fileName')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить документ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = _hasUnsavedChanges ? 'Есть изменения' : 'Сохранено';
        });
      }
    }
  }

  Future<void> _exportPng() async {
    try {
      final bytes = await DocumentExport.png(_controller.document);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Экспортировать холст в PNG',
        fileName: 'FlutterDraw.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
        bytes: bytes,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PNG экспортирован: ${path.split(RegExp(r'[/\\\\]')).last}')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать PNG: $error')),
      );
    }
  }

  Future<void> _exportSvg() async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(DocumentExport.svg(_controller.document)));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Экспортировать холст в SVG',
        fileName: 'FlutterDraw.svg',
        type: FileType.custom,
        allowedExtensions: ['svg'],
        bytes: bytes,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SVG экспортирован: ${path.split(RegExp(r'[/\\\\]')).last}')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать SVG: $error')),
      );
    }
  }

  Future<void> _exportExcalidraw() async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(_excalidrawCodec.encode(_controller.document)));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Экспортировать в Excalidraw',
        fileName: 'FlutterDraw.excalidraw',
        type: FileType.custom,
        allowedExtensions: ['excalidraw'],
        bytes: bytes,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excalidraw экспортирован: ${path.split(RegExp(r'[/\\\\]')).last}')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать Excalidraw: $error')),
      );
    }
  }

  Future<void> _saveDocumentAs() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveStatus = 'Сохранение…';
    });
    try {
      final content = _codec.encode(_controller.document);
      final bytes = Uint8List.fromList(utf8.encode(content));
      final suggestedName = _documentTitle == 'Без названия'
          ? 'Без названия.flutterdraw'
          : (_documentTitle.endsWith('.flutterdraw')
              ? _documentTitle
              : '$_documentTitle.flutterdraw');
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить документ FlutterDraw',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['flutterdraw'],
        bytes: bytes,
      );
      if (savedPath == null) return;
      final fileName = savedPath.split(RegExp(r'[/\\\\]')).last;
      if (!kIsWeb) _documentPath = savedPath;
      _savedContent = _codec.encode(_controller.document, pretty: false);
      if (mounted) {
        setState(() {
          _documentTitle = fileName;
          _saveStatus = 'Сохранено';
        });
      }
      _lastAutosavedContent = null;
      _lastAutosavedTitle = null;
      await _writeAutosave();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Документ сохранён: $fileName')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить документ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = _hasUnsavedChanges ? 'Есть изменения' : 'Сохранено';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleWorkspaceKeyEvent,
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _WorkspaceHeader(
              controller: _controller,
              title: _documentTitle,
              onNew: _newDocument,
              onOpen: _openDocument,
              onSave: _saveDocument,
              onSaveAs: _saveDocumentAs,
              onExportPng: _exportPng,
              onExportSvg: _exportSvg,
              onExportExcalidraw: _exportExcalidraw,
              saveStatus: _saveStatus,
            ),
            Expanded(
              child: Row(
                children: [
                  _ToolRail(controller: _controller),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CanvasViewport(controller: _controller),
                            const Positioned(
                              top: 10,
                              right: 10,
                              child: CanvasHelpOverlay(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 272, child: Column(children: [
                    Expanded(child: _InspectorPanel(controller: _controller)),
                    SizedBox(height: 230, child: _LayersPanel(controller: _controller)),
                  ])),
                ],
              ),
            ),
            _StatusBar(controller: _controller),
          ],
        ),
      ),
    ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.controller,
    required this.title,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onExportPng,
    required this.onExportSvg,
    required this.onExportExcalidraw,
    required this.saveStatus,
  });

  final CanvasEditorController controller;
  final String title;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onExportPng;
  final VoidCallback onExportSvg;
  final VoidCallback onExportExcalidraw;
  final String saveStatus;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
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
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          Text(saveStatus, style: Theme.of(context).textTheme.labelSmall),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Файл',
            onSelected: (value) {
              switch (value) {
                case 'new':
                  onNew();
                  break;
                case 'open':
                  onOpen();
                  break;
                case 'save':
                  onSave();
                  break;
                case 'saveAs':
                  onSaveAs();
                  break;
                case 'exportPng':
                  onExportPng();
                  break;
                case 'exportSvg':
                  onExportSvg();
                  break;
                case 'exportExcalidraw':
                  onExportExcalidraw();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'new',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.note_add_outlined),
                  title: Text('Новый'),
                  trailing: Text('Ctrl+N'),
                ),
              ),
              PopupMenuItem(
                value: 'open',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.folder_open_outlined),
                  title: Text('Открыть…'),
                  trailing: Text('Ctrl+O'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'save',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.save_outlined),
                  title: Text('Сохранить'),
                  trailing: Text('Ctrl+S'),
                ),
              ),
              PopupMenuItem(
                value: 'saveAs',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.save_as_outlined),
                  title: Text('Сохранить как…'),
                  trailing: Text('Ctrl+Shift+S'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'exportPng',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.image_outlined),
                  title: Text('Экспорт PNG…'),
                ),
              ),
              PopupMenuItem(
                value: 'exportSvg',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.code),
                  title: Text('Экспорт SVG…'),
                ),
              ),
              PopupMenuItem(
                value: 'exportExcalidraw',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.import_export),
                  title: Text('Экспорт Excalidraw…'),
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu),
                  SizedBox(width: 6),
                  Text('Файл'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Дублировать (Ctrl+D)',
            onPressed: controller.duplicateSelection,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'На передний план (Ctrl+])',
            onPressed: controller.bringSelectionToFront,
            icon: const Icon(Icons.flip_to_front),
          ),
          IconButton(
            tooltip: 'На задний план (Ctrl+[)',
            onPressed: controller.sendSelectionToBack,
            icon: const Icon(Icons.flip_to_back),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => IconButton(
              tooltip: 'Отменить (Ctrl+Z)',
              onPressed: controller.canUndo ? controller.undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => IconButton(
              tooltip: 'Повторить (Ctrl+Shift+Z)',
              onPressed: controller.canRedo ? controller.redo : null,
              icon: const Icon(Icons.redo_rounded),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Новый документ', onPressed: onNew,
            icon: const Icon(Icons.note_add_outlined)),
          IconButton(tooltip: 'Открыть документ', onPressed: onOpen,
            icon: const Icon(Icons.folder_open_outlined)),
          FilledButton.tonalIcon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Сохранить'),
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
              _ToolButton(
                controller: controller,
                tool: CanvasTool.ellipse,
                icon: Icons.circle_outlined,
                tooltip: 'Эллипс',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.diamond,
                icon: Icons.diamond_outlined,
                tooltip: 'Ромб',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.line,
                icon: Icons.timeline,
                tooltip: 'Линия',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.arrow,
                icon: Icons.arrow_right_alt,
                tooltip: 'Стрелка',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.text,
                icon: Icons.text_fields,
                tooltip: 'Текст',
              ),
              _ToolButton(
                controller: controller,
                tool: CanvasTool.freehand,
                icon: Icons.gesture,
                tooltip: 'Рисование от руки',
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
  const _InspectorPanel({required this.controller});
  final CanvasEditorController controller;

  static const _palette = <int>[
    0xFF252525, 0xFF6B7280, 0xFFDC2626, 0xFFEA580C,
    0xFFD97706, 0xFF16A34A, 0xFF0891B2, 0xFF2563EB,
    0xFF7C3AED, 0xFFDB2777, 0xFFFFFFFF,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final selected = controller.selectedElements;
          if (selected.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Свойства', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('Выберите один или несколько объектов на холсте.',
                  style: Theme.of(context).textTheme.bodySmall),
              ],
            );
          }
          final element = selected.first;
          final isText = selected.length == 1 && element.type == DrawingElementType.text;
          final hasFill = selected.any((e) =>
              e.type == DrawingElementType.rectangle ||
              e.type == DrawingElementType.ellipse ||
              e.type == DrawingElementType.diamond);
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Свойства', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                _section(context, element.type == DrawingElementType.text ? 'Цвет текста' : 'Цвет обводки'),
                _colorChoices(
                  selectedColor: element.strokeColor,
                  onSelected: (color) => controller.updateSelectedProperties(strokeColor: color),
                ),
                const SizedBox(height: 14),
                if (hasFill) ...[
                  _section(context, 'Заливка'),
                  _colorChoices(
                    selectedColor: element.fillColor,
                    allowNone: true,
                    onSelected: (color) => controller.updateSelectedProperties(fillColor: color),
                  ),
                  const SizedBox(height: 14),
                ],
                if (element.type != DrawingElementType.text) ...[
                  _section(context, 'Толщина линии: ${element.strokeWidth.toStringAsFixed(1)}'),
                  Slider(
                    min: 0.5, max: 12, divisions: 23,
                    value: element.strokeWidth.clamp(0.5, 12).toDouble(),
                    onChanged: (value) => controller.updateSelectedProperties(strokeWidth: value),
                  ),
                  const SizedBox(height: 8),
                ],
                _section(context, 'Непрозрачность: ${(element.opacity * 100).round()}%'),
                Slider(
                  min: 0.05, max: 1, divisions: 19,
                  value: element.opacity.clamp(0.05, 1).toDouble(),
                  onChanged: (value) => controller.updateSelectedProperties(opacity: value),
                ),
                if (isText) ...[
                  const Divider(height: 26),
                  _section(context, 'Содержимое'),
                  TextFormField(
                    key: ValueKey('text-${element.id}'),
                    initialValue: element.text,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(), isDense: true,
                    ),
                    onChanged: controller.updateSelectedText,
                  ),
                  const SizedBox(height: 14),
                  _section(context, 'Шрифт'),
                  DropdownButtonFormField<String>(
                    initialValue: const ['Roboto', 'Arial', 'Georgia', 'Courier New', 'Times New Roman'].contains(element.fontFamily) ? element.fontFamily : 'Roboto',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(), isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                      DropdownMenuItem(value: 'Arial', child: Text('Arial')),
                      DropdownMenuItem(value: 'Georgia', child: Text('Georgia')),
                      DropdownMenuItem(value: 'Courier New', child: Text('Courier New')),
                      DropdownMenuItem(value: 'Times New Roman', child: Text('Times New Roman')),
                    ],
                    onChanged: (value) {
                      if (value != null) controller.updateSelectedProperties(fontFamily: value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _section(context, 'Размер шрифта: ${element.fontSize.round()}'),
                  Slider(
                    min: 10, max: 96, divisions: 43,
                    value: element.fontSize.clamp(10, 96).toDouble(),
                    onChanged: controller.setSelectedTextFontSize,
                  ),
                  _section(context, 'Выравнивание'),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left)),
                      ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center)),
                      ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right)),
                    ],
                    selected: {const ['left', 'center', 'right'].contains(element.textAlign) ? element.textAlign : 'left'},
                    onSelectionChanged: (values) =>
                      controller.updateSelectedProperties(textAlign: values.first),
                  ),
                  const SizedBox(height: 12),
                  _section(context, 'Размер текстового блока'),
                  _dimensionField(context, 'Ширина', element.width,
                    (value) => controller.setSelectedTextBlockSize(width: value)),
                  const SizedBox(height: 8),
                  _dimensionField(context, 'Высота', element.height,
                    (value) => controller.setSelectedTextBlockSize(height: value)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _colorChoices({
    required int selectedColor,
    required ValueChanged<int> onSelected,
    bool allowNone = false,
  }) {
    return Wrap(
      spacing: 7, runSpacing: 7,
      children: [
        if (allowNone)
          InkWell(
            onTap: () => onSelected(0x00000000),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selectedColor == 0 ? Colors.blue : Colors.grey,
                  width: selectedColor == 0 ? 2.5 : 1,
                ),
              ),
              child: const Icon(Icons.block, size: 15),
            ),
          ),
        for (final color in _palette)
          InkWell(
            onTap: () => onSelected(color),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: Color(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selectedColor == color ? Colors.blue : Colors.black26,
                  width: selectedColor == color ? 2.5 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _dimensionField(BuildContext context, String label, double value,
      ValueChanged<double> onSubmitted) {
    return Row(
      children: [
        SizedBox(width: 58, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Expanded(
          child: TextFormField(
            key: ValueKey('$label-${value.round()}'),
            initialValue: value.round().toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              suffixText: 'px', isDense: true, border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (raw) {
              final parsed = double.tryParse(raw);
              if (parsed != null && parsed.isFinite) onSubmitted(parsed);
            },
          ),
        ),
      ],
    );
  }
}

class _LayersPanel extends StatelessWidget {
  const _LayersPanel({required this.controller});
  final CanvasEditorController controller;

  String _label(DrawingElement element) {
    if (element.type == DrawingElementType.text && element.text.trim().isNotEmpty) {
      final value = element.text.replaceAll('\n', ' ').trim();
      return value.length > 22 ? '${value.substring(0, 22)}…' : value;
    }
    return switch (element.type) {
      DrawingElementType.rectangle => 'Прямоугольник',
      DrawingElementType.ellipse => 'Эллипс',
      DrawingElementType.diamond => 'Ромб',
      DrawingElementType.line => 'Линия',
      DrawingElementType.arrow => 'Стрелка',
      DrawingElementType.freehand => 'Рисунок от руки',
      DrawingElementType.text => 'Текст',
    };
  }

  IconData _icon(DrawingElementType type) => switch (type) {
    DrawingElementType.rectangle => Icons.rectangle_outlined,
    DrawingElementType.ellipse => Icons.circle_outlined,
    DrawingElementType.diamond => Icons.diamond_outlined,
    DrawingElementType.line => Icons.timeline,
    DrawingElementType.arrow => Icons.arrow_right_alt,
    DrawingElementType.freehand => Icons.gesture,
    DrawingElementType.text => Icons.text_fields,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final layers = controller.document.elements.reversed.toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.layers_outlined, size: 18),
              const SizedBox(width: 7),
              Expanded(child: Text('Слои', style: Theme.of(context).textTheme.titleSmall)),
              Text('${layers.length}', style: Theme.of(context).textTheme.labelSmall),
            ]),
            SwitchListTile(dense: true, contentPadding: EdgeInsets.zero,
              title: const Text('Привязка к сетке'), value: controller.snapToGrid,
              onChanged: controller.setSnapToGrid),
            SwitchListTile(dense: true, contentPadding: EdgeInsets.zero,
              title: const Text('Умные направляющие'), value: controller.snapToGuides,
              onChanged: controller.setSnapToGuides),
            const Divider(height: 8),
            Expanded(child: layers.isEmpty
              ? Center(child: Text('Нет объектов', style: Theme.of(context).textTheme.bodySmall))
              : ReorderableListView.builder(
                  buildDefaultDragHandles: true,
                  itemCount: layers.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final reordered = [...layers];
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    controller.reorderLayers(reordered.map((e) => e.id).toList());
                  },
                  itemBuilder: (context, index) {
                    final element = layers[index];
                    final selected = controller.selectedElementIds.contains(element.id);
                    final groupId = element.extraData['flutterdrawGroupId'];
                    return ListTile(
                      key: ValueKey(element.id), dense: true,
                      visualDensity: VisualDensity.compact,
                      selected: selected, selectedTileColor: colors.secondaryContainer,
                      leading: Icon(_icon(element.type), size: 17),
                      title: Text(_label(element), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: groupId is String ? const Text('Группа') : null,
                      onTap: () => controller.selectElementById(element.id),
                    );
                  },
                )),
          ]);
        },
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
          final count = controller.document.elements.length;
          final selectedCount = controller.selectedElementIds.length;
          return Row(
            children: [
              Text(
                selectedCount > 0 ? 'Выбрано: $selectedCount' : 'Готово',
                style: Theme.of(context).textTheme.labelSmall,
              ),
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
