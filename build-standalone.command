#!/bin/bash
# Double-click this file on a Mac with Xcode installed to build a portable application.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
DEST="$ROOT/dist"
mkdir -p "$DEST"
echo 'Building Universal (Apple Silicon + Intel) macOS .app ...'
xcodebuild -project SquareRolloPrinter.xcodeproj \
  -scheme SquareRolloPrinter -configuration Release \
  -sdk macosx -destination 'generic/platform=macOS' \
  -derivedDataPath "$ROOT/.build" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
APP="$ROOT/.build/Build/Products/Release/SquareRolloPrinter.app"
if [[ ! -d "$APP" ]]; then echo 'Application bundle not found'; exit 1; fi
rm -rf "$DEST/SquareRolloPrinter.app"
/usr/bin/ditto "$APP" "$DEST/SquareRolloPrinter.app"
# Local ad-hoc signing; no Developer Program membership required.
/usr/bin/codesign --force --deep --sign - "$DEST/SquareRolloPrinter.app"
rm -f "$DEST/SquareRolloPrinter-macOS.zip"
/usr/bin/ditto -c -k --keepParent "$DEST/SquareRolloPrinter.app" "$DEST/SquareRolloPrinter-macOS.zip"
echo
echo "SUCCESS: $DEST/SquareRolloPrinter.app"
echo "Portable ZIP: $DEST/SquareRolloPrinter-macOS.zip"
/usr/bin/open "$DEST"
