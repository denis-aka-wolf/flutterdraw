# Branding and app icons

## FlutterDraw logo

The primary FlutterDraw logo is stored at `docs/img/logo.png`.

![FlutterDraw logo](img/logo.png)

Use this image in project documentation and promotional materials. Keep its aspect ratio and transparent background; do not stretch, recolor, or crop the mark.

## Application icon

The same high-resolution PNG is the source image for the application launcher icons. The generator configuration is maintained in the root `pubspec.yaml`:

- Android
- Windows
- Web (favicon and PWA icons)

Generate or refresh the platform icons from the repository root:

```powershell
flutter pub get
dart run launcher_icons
```

The release script `scripts/build_release.ps1` runs this generator automatically before analysis, tests, and packaging.

Platform folders such as `windows/`, `android/`, and `web/` are excluded from this repository and are created locally for builds. Generated launcher assets therefore appear in those local platform folders rather than being committed separately. The source logo in `docs/img/logo.png` remains the single source of truth.
