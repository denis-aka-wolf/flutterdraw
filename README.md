# FlutterDraw

FlutterDraw is a cross-platform hand-drawn whiteboard built with Flutter.

## Goals

- Infinite canvas with a sketch-like visual style.
- Desktop-first experience for Windows, macOS and Linux.
- Shared core for Web, Android and iOS.
- Import and export of the Excalidraw .excalidraw document format.
- Native Flutter rendering and interaction. The Excalidraw React application is a behavioral and format reference, not an embedded runtime.

## Target platforms

Windows, macOS, Linux, Web, Android and iOS.

## Project status

Early development. The canvas foundation and first drawing/editing tools are implemented:

- Rectangle, ellipse and diamond shapes.
- Straight lines, arrows and freehand strokes.
- Single and marquee multi-selection.
- Moving and resizing selected shapes.
- Copy, paste and duplicate.
- Bring selected objects to front or send them to back.
- Zoom, pan and adaptive canvas grid.

Text, images, document persistence, undo/redo and Excalidraw import/export remain planned work.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Space + drag | Pan the canvas |
| Middle mouse + drag | Pan the canvas |
| Mouse wheel | Zoom around the pointer |
| Shift + click | Add/remove an element from selection |
| Drag on empty canvas | Marquee selection |
| Delete / Backspace | Delete selected elements |
| Escape | Cancel current gesture and clear selection |
| Ctrl/Cmd + C | Copy selected elements |
| Ctrl/Cmd + V | Paste copied elements |
| Ctrl/Cmd + D | Duplicate selected elements |
| Ctrl/Cmd + ] | Bring selection to front |
| Ctrl/Cmd + [ | Send selection to back |

## Architecture

See docs/ARCHITECTURE.md for the architecture, module boundaries, document model and implementation roadmap.

## Development

Install Flutter, then run:

    flutter pub get
    flutter analyze
    flutter test
    flutter run -d windows

Use macos, linux, chrome, android or an available iOS simulator/device for other targets.

## Excalidraw compatibility

The compatibility layer will preserve the Excalidraw document envelope (type, version, source, elements, appState, files) and round-trip fields that FlutterDraw does not yet understand wherever possible. Compatibility will be tested against real fixture files.

## License

The project license will be finalized before the first public release. Third-party code and algorithms will retain their original license notices.
