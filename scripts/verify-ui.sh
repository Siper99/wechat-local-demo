#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --spec project-personal.yml
# SIM_RUNTIME 可限定系统版本（如 iOS-26），默认任意；优先 iPhone 16，其次 iPhone 17
simulator_id="$(xcrun simctl list devices available -j | SIM_RUNTIME="${SIM_RUNTIME:-}" python3 -c '
import json, os, sys
d = json.load(sys.stdin)
want = os.environ["SIM_RUNTIME"]
phones = [x for key, group in d["devices"].items() if want in key for x in group if "iPhone" in x["name"]]
pick = next((x for x in phones if x["name"] == "iPhone 16"), None) or next((x for x in phones if x["name"] == "iPhone 17"), None) or phones[0]
print(pick["udid"])
')"
xcrun simctl list devices | grep "$simulator_id" || true
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
