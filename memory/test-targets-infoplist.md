---
name: test-targets-infoplist
description: TapeScrapeTests and TapeScrapeUITests require GENERATE_INFOPLIST_FILE: YES in project.yml or code signing fails
metadata:
  type: feedback
---

Without `GENERATE_INFOPLIST_FILE: YES` in the test targets' build settings, xcodebuild refuses to code-sign them: "Cannot code sign because the target does not have an Info.plist file."

**Why:** Discovered during 00-002-four-hooks when running `xcodebuild test`.

**How to apply:** Both `TapeScrapeTests` and `TapeScrapeUITests` targets in `project.yml` must have `GENERATE_INFOPLIST_FILE: YES` under `settings.base`.
