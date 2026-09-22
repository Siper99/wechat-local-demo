#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script requires macOS and Xcode. On Windows, run the GitHub Actions workflow."
  exit 1
fi
command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen"; exit 1; }
xcodebuild -version
xcodegen generate --spec project-personal.yml
mkdir -p build
# 每次使用独立目录，防止旧构建内容进入 IPA。
work_dir="$(mktemp -d "$PWD/build/ipa.XXXXXX")"
xcodebuild \
  -project QingLiaoPersonal.xcodeproj \
  -scheme QingLiao \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$work_dir/QingLiao.xcarchive" \
  -derivedDataPath "$work_dir/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive

app_path="$work_dir/QingLiao.xcarchive/Products/Applications/QingLiao.app"
test -f "$app_path/Info.plist"
mkdir -p "$work_dir/package/Payload"
ditto "$app_path" "$work_dir/package/Payload/QingLiao.app"
(cd "$work_dir/package" && /usr/bin/zip -qry "$work_dir/WeChat-Simulator-unsigned.ipa" Payload)
cp "$work_dir/WeChat-Simulator-unsigned.ipa" build/WeChat-Simulator-unsigned.ipa
echo "Created build/WeChat-Simulator-unsigned.ipa — sign and install with AltStore Classic."
