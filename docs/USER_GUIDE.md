# FlutterDraw user guide

FlutterDraw is a cross-platform, sketch-style whiteboard. This guide describes the functionality currently available in the application.

## Workspace

The workspace is organized around four areas:

- **Canvas:** the drawing surface. The grid adapts to the current zoom level.
- **Tool rail:** select, hand, rectangle, ellipse, diamond, line, arrow, text and freehand tools.
- **Inspector:** edit the selected element's stroke, fill, opacity and text properties.
- **Help overlay:** open the translucent "Подсказка" panel in the upper-right corner of the canvas. The panel can be resized from its lower-left handle; its size is remembered between launches.

## Drawing and navigation

1. Choose a tool from the left toolbar.
2. Drag on the canvas to create a shape or stroke. For text, click the canvas and enter text.
3. Choose the selection tool to select, move or resize elements.
4. Shift-click adds an element to the current selection. Drag on an empty area to create a selection marquee.
5. Use the hand tool, Space + drag, or the middle mouse button to pan the canvas.
6. Use the mouse wheel to zoom around the pointer.

The inspector changes according to the selected element. Text can also be edited directly on the canvas by double-clicking it. Right-click the canvas or an object to open the context menu. It includes clipboard, grouping, alignment, z-order and delete actions.

## Documents and files

Use the **Файл** menu in the top bar or the keyboard shortcuts below.

- **New:** starts an empty document.
- **Open:** opens a previously saved `.flutterdraw` document.
- **Save:** writes changes to the currently opened/saved file. If the document has no file path yet, Save opens the save dialog.
- **Save as:** opens the platform save dialog and saves a separate `.flutterdraw` file.
- **Export PNG:** renders the complete document bounds to a transparent PNG at 2× resolution, regardless of the current viewport.
- **Export SVG:** writes the document's vector geometry and text as an SVG file.

When creating a new document or opening another one, FlutterDraw asks for confirmation if the current document has unsaved changes.

### Autosave and recovery

The editor automatically writes a recovery snapshot to local application preferences after a short pause (currently 700 ms) following document changes. The snapshot contains the document and its title, not the current camera position or selection.

When the application starts, it attempts to restore the latest available session. Recovery is a convenience copy, not a replacement for saving a named `.flutterdraw` file to a location you control. Keep manual backups of important work.

The header shows the current save state, such as **Сохранено**, **Есть изменения**, **Автосохранено** or **Восстановлено**.

## Groups, alignment and layers

Select two or more objects and choose **Сгруппировать** from the context menu, or press Ctrl/Cmd + G. Clicking a member of a group selects the entire group. Use **Разгруппировать** or Ctrl/Cmd + Shift + G to remove the group relationship without deleting its objects.

The context menu provides left, horizontal-center, right, top, vertical-center and bottom alignment for multi-selection. Alignment uses the combined bounds of the selected objects.

The **Слои** panel is docked below the inspector on the right. It lists topmost objects first. Select a row to select its object (or its entire group), and drag rows to change stacking order. The switches control grid snapping and smart alignment guides. Grid snapping uses a 24-world-unit grid; smart guides snap nearby object edges and centers while moving a selection.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Ctrl/Cmd + N | New document |
| Ctrl/Cmd + O | Open a `.flutterdraw` document |
| Ctrl/Cmd + S | Save document (or open Save As for a new document) |
| Ctrl/Cmd + Shift + S | Save document as… |
| Ctrl/Cmd + G | Group selected elements |
| Ctrl/Cmd + Shift + G | Ungroup selected elements |
| Right-click | Open the context menu |
| Ctrl/Cmd + Z | Undo |
| Ctrl/Cmd + Shift + Z | Redo |
| Ctrl/Cmd + Y | Redo |
| Ctrl/Cmd + C | Copy selected elements |
| Ctrl/Cmd + V | Paste |
| Ctrl/Cmd + D | Duplicate |
| Ctrl/Cmd + ] | Bring selection to front |
| Ctrl/Cmd + [ | Send selection to back |
| Delete / Backspace | Delete selected elements |
| Escape | Cancel the current gesture or clear selection |
| Space + drag | Pan the canvas |
| Middle mouse + drag | Pan the canvas |
| Mouse wheel | Zoom around the pointer |
| Shift + click | Add/remove an element from selection |

On macOS, use Command where the shortcut is written as Ctrl/Cmd.

## Current format and compatibility

The native `.flutterdraw` file is a JSON document handled by FlutterDraw's own codec. It is distinct from the Excalidraw `.excalidraw` format. Excalidraw import/export is planned and is not currently available in the user interface.

## Known limitations

- Image elements are not available yet. SVG export uses clean vector geometry and does not reproduce the editor's seeded sketch jitter exactly.
- Autosave recovery is local to the application installation/profile. It is not cloud synchronization.
- The current file workflow should be treated as an early implementation; keep backups of important documents.
