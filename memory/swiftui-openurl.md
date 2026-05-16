---
name: swiftui-openurl
description: onOpenURL must be applied to a View (ContentView), not to a Scene/WindowGroup — attaching to WindowGroup is a compile error
metadata:
  type: feedback
---

`.onOpenURL` is a SwiftUI `View` modifier, not a `Scene` modifier. Applying it to `WindowGroup` causes: "value of type 'WindowGroup<ContentView>' has no member 'onOpenURL'".

**Why:** Hit this during 00-002-four-hooks when wiring the tapescrape:// deep link handler.

**How to apply:** Place `.onOpenURL` on the root `View` (e.g. `ContentView` or `TabView`), not on `WindowGroup`.
