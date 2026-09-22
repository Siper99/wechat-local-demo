#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --spec project-personal.yml
simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); phones=[x for group in d["devices"].values() for x in group if "iPhone" in x["name"]]; print(next((x["udid"] for x in phones if x["name"] == "iPhone 16"), phones[0]["udid"]))')"
xcrun simctl boot "$simulator_id" || true
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl ui "$simulator_id" appearance light
xcrun simctl status_bar "$simulator_id" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
xcodebuild test \
  -project QingLiaoPersonal.xcodeproj \
  -scheme QingLiao \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -parallel-testing-enabled NO \
  -resultBundlePath build/UI.xcresult \
  CODE_SIGNING_ALLOWED=NO
