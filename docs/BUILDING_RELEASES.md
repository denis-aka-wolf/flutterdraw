# Локальная сборка релиза

GitHub Actions для сборки не требуется. Скрипт запускается на Windows-компьютере с установленным Flutter SDK.

## Что собирается

По умолчанию скрипт проверяет код и собирает три варианта:

- Windows x64: ZIP с приложением и необходимыми runtime-файлами.
- Android: release APK.
- Web: ZIP с содержимым build/web.

Linux и macOS требуют соответствующих сред сборки и в этот Windows-скрипт не входят.

## Требования

- Flutter stable, доступный из PATH.
- Для Windows: Visual Studio с workload **Desktop development with C++**.
- Для Android: Android SDK, настроенный через flutter doctor, и принятые Android SDK licenses.
- PowerShell 5.1 или PowerShell 7.

Проверь окружение командой:

    flutter doctor -v

## Запуск

Из корня репозитория:

    .\scripts\build_release.ps1

Можно собрать только отдельные платформы:

    .\scripts\build_release.ps1 -Platforms Windows
    .\scripts\build_release.ps1 -Platforms Android,Web

Перед сборкой скрипт выполняет:

1. flutter pub get
2. flutter analyze
3. flutter test

Если платформенные каталоги Windows, Android или Web отсутствуют, скрипт создаёт их командой flutter create. Это может добавить или обновить платформенные файлы в рабочем дереве. После первого запуска проверь git status и сохрани необходимые изменения в репозитории.

## Результаты

Артефакты появятся в каталоге dist, внутри папки версии из pubspec.yaml, например:

    dist/
      v0.1.0/
        BUILD-INFO.txt
        flutterdraw-windows-x64.zip
        flutterdraw-android.apk
        flutterdraw-web.zip

Повторный запуск пересоздаёт только папку текущей версии dist/vX.Y.Z. Остальные каталоги в dist не затрагиваются.

## Публикация на GitHub

1. Открой репозиторий и перейди в **Releases**.
2. Нажми **Draft a new release**.
3. Выбери существующий тег версии, например v0.1.0, либо создай новый.
4. Прикрепи файлы из dist/vX.Y.Z.
5. Заполни описание релиза и нажми **Publish release**.

Для следующего релиза сначала обнови version в pubspec.yaml, затем запусти скрипт и опубликуй полученные файлы.
