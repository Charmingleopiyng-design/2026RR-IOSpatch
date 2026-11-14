#!/bin/sh
set -eu
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild is required. This framework cannot be compiled on Linux."
  exit 2
fi
xcodebuild -project RecNetRedirect.xcodeproj \
  -scheme RecNetRedirect \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  build
