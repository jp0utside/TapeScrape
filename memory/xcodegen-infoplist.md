---
name: xcodegen-infoplist
description: XcodeGen regenerates Info.plist on every run, overwriting direct edits — all Info.plist properties must be declared in project.yml
metadata:
  type: feedback
---

Direct edits to `TapeScrape/Info.plist` are overwritten every time `xcodegen generate` is run. All Info.plist properties (including URL types, background modes, etc.) must be declared under the `info.properties` section of `project.yml`.

**Why:** Learned when adding `CFBundleURLTypes` for the `tapescrape://` scheme — the edit was wiped on the next `xcodegen generate` call.

**How to apply:** For any Info.plist change, edit `project.yml` → `targets.TapeScrape.info.properties`, then run `xcodegen generate`.
