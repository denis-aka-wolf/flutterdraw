# FlutterDraw architecture

## Decisions

- Targets: Windows, macOS, Linux, Web, Android, iOS.
- Delivery order: Desktop first. Windows is the first development target.
- Rendering and interaction: native Flutter, not a WebView embedding the React Excalidraw application.
- Excalidraw JSON import/export is a first-class feature.
- Domain and geometry are pure Dart and must not depend on Flutter widgets or platform APIs.

## Layered architecture

```text
Presentation (Flutter widgets, workspace, toolbar, inspector, shortcuts)
        |
Application (commands, tool orchestration, selection, undo/redo)
        |
Domain (document, elements, geometry, styles, tool contracts)
        |
Infrastructure (serialization, persistence, assets, export)
        |
Platform adapters (files, clipboard, keyboard, window integration)
```

Dependencies point inward. Domain must not import Flutter, platform plugins, or storage implementations. Infrastructure implements ports defined at the application boundary.

## Proposed source layout

```text
lib/
  main.dart
  app/                 # app bootstrap, theme, shortcuts
  core/                # geometry primitives, IDs, shared utilities
  domain/
    document/          # document and element collection
    elements/          # rectangle, ellipse, arrow, freehand, text, image
    styles/            # stroke, fill, opacity, roughness
    tools/             # tool contracts and normalized pointer events
  application/
    canvas/            # canvas controller and viewport state
    commands/          # create, update, delete, transform
    selection/         # hit testing and selection model
    history/           # undo/redo transactions
  infrastructure/
    serialization/     # Excalidraw and native FlutterDraw codecs
    persistence/       # document repositories and autosave
    assets/            # image asset storage
    export/            # PNG, SVG and clipboard encoders
  platform/            # file picker, clipboard, window adapters
  features/
    workspace/         # workspace composition
    canvas/            # viewport widget and render backend
    toolbar/
test/
  domain/
  application/
  serialization/
  rendering/
  fixtures/excalidraw/
integration_test/
```

## Document and coordinate model

The document contains elements in world coordinates. Camera position, zoom, active tool, hover state, and selection handles belong to transient editor state, not the document.

Initial element kinds: rectangle, ellipse, diamond, line, arrow, freehand, text, image. Every element has a stable ID, position, dimensions, rotation, style, opacity, roughness, deterministic seed, and type-specific geometry.

Core invariants:
- World coordinates are independent of screen pixels.
- Zoom and pan never rewrite element geometry.
- Rendering is deterministic for a given element seed and style.
- UI-only state is never serialized as document content.
- Duplicate/paste creates new IDs; edits preserve IDs.
- Unknown imported fields should be retained whenever possible.

## Canvas and rendering

Use one viewport transform as the source of truth: worldToScreen, screenToWorld, worldRectToScreen, and screenDeltaToWorld. The canvas widget normalizes input; an interaction controller routes events to the active tool. The renderer paints an immutable document snapshot and only the visible region.

Rendering stages:
1. Geometry generation and bounds.
2. Style resolution.
3. Flutter Canvas paint backend.
4. Optional caches keyed by element revision and render scale.

Use a separate sketch renderer. Rough.js is a behavioral reference for rough geometric strokes; perfect-freehand is a reference for pressure-aware freehand outlines. Review exact upstream and dependency licenses before porting code. Prefer a Dart-native implementation.

## Interaction

Tools are state machines, not conditionals scattered through widgets. They receive normalized pointer events in world coordinates and emit previews or document commands.

Desktop input includes mouse, trackpad, keyboard shortcuts, and context menus. Touch input includes one-finger drawing/selection and two-finger pan/zoom. Stylus pressure is optional where available.

## History

Persistent edits are commands or transactions. A continuous gesture such as drawing a stroke or dragging a shape becomes one undo entry. Start with immutable snapshots for correctness; optimize to reversible patches only after profiling.

## File formats and Excalidraw compatibility

Do not use Excalidraw JSON as the internal domain model. Implement a dedicated codec that maps between the internal document and Excalidraw's envelope:

- type
- version
- source
- elements
- appState
- files

Compatibility milestones:
1. Import/export common shapes, lines, arrows, text, and styles.
2. Preserve unknown fields and unsupported elements.
3. Support image data and file references.
4. Handle groups, bindings, frames, text metrics, and edge cases.
5. Maintain fixture-based round-trip tests against real Excalidraw files.

An element that cannot yet be rendered must not be silently discarded during import/export.

The native FlutterDraw format will have its own versioned JSON envelope. Image bytes are stored as assets addressed by stable IDs; elements reference assets rather than platform file paths.

## Platform strategy

Shared domain, application, geometry, serialization, and rendering code. Platform adapters provide file access, clipboard, downloads, and window integration. Avoid dart:io in code shared with Web. Desktop gets the first complete workflow; mobile receives adaptive panels and touch-first controls later.

## Testing

- Domain tests: geometry, transforms, invariants, IDs.
- Codec tests: fixtures, import/export, unknown-field preservation.
- Application tests: tool state machines and undo/redo.
- Widget tests: toolbar, canvas input, selection.
- Golden tests: fixed seeds and fixed render scales.
- Integration tests: create, save, reopen, export.

## Roadmap

### M0: Foundation
- Flutter project and all six platform folders.
- App shell, theme, responsive workspace.
- Canvas viewport, coordinate transform, grid, pan/zoom.
- Domain/application boundaries and baseline tests.

### M1: Drawing
- Rectangle, ellipse, diamond, line, arrow, freehand.
- Selection, move, resize, delete.

### M2: Editing
- Text and images, style inspector, multi-select, z-order.
- Undo/redo, duplicate, copy/paste.

### M3: Documents
- Native format, open/save, autosave.
- Excalidraw import/export and fixture suite.

### M4: Sketch renderer
- Rough geometric strokes and pressure-aware freehand.
- Deterministic seeds and visual regression tests.

### M5: Desktop release
- Menus, shortcuts, native dialogs, packaging and smoke tests.

### M6: Web and mobile
- Browser persistence/downloads, touch/stylus, adaptive layout.

## Guardrails

- Do not embed the React application in a WebView.
- Do not couple domain objects to Flutter widgets or Canvas APIs.
- Do not store viewport pixels in document elements.
- Do not silently drop unsupported imported fields/elements.
- Do not optimize before profiling representative large scenes.