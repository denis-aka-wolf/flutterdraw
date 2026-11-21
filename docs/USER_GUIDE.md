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

The inspector changes according to the selected element. Text can also be edited directly on the canvas by double-clicking it.

## Documents and files

Use the **Файл** menu in the top bar or the keyboard shortcuts below.

- **New:** starts an empty document.
- **Open:** opens a previously saved `.flutterdraw` document.
- **Save:** opens the platform save dialog and writes the current document in FlutterDraw's native JSON format.

When creating a new document or opening another one, FlutterDraw asks for confirmation if the current document has unsaved changes.

### Autosave and recovery

The editor automatically writes a recovery snapshot to local application preferences after a short pause (currently 700 ms) following document changes. The snapshot contains the document and its title, not the current camera position or selection.

When the application starts, it attempts to restore the latest available session. Recovery is a convenience copy, not a replacement for saving a named `.flutterdraw` file to a location you control. Keep manual backups of important work.

The header shows the current save state, such as **Сохранено**, **Есть изменения**, **Автосохранено** or **Восстановлено**.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Ctrl/Cmd + N | New document |
| Ctrl/Cmd + O | Open a `.flutterdraw` document |
| Ctrl/Cmd + S | Save document |
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

- Image elements and PNG/SVG export are not available yet.
- Autosave recovery is local to the application installation/profile. It is not cloud synchronization.
- The current file workflow should be treated as an early implementation; keep backups of important documents.
