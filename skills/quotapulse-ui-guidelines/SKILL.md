---
name: quotapulse-ui-guidelines
description: Apply QuotaPulse SwiftUI UI conventions when adding or editing settings, forms, inputs, toggles, buttons, or user-visible controls. Use this skill for any SettingsView or form-layout change.
---

# QuotaPulse UI guidelines

Use this skill before modifying `Sources/QuotaPulse/Views/SettingsView.swift` or adding a settings-like SwiftUI form. Read [`docs/UI_GUIDELINES.md`](../../docs/UI_GUIDELINES.md) for the complete project convention.

## Required approach

- Keep the existing `Form` + `.formStyle(.grouped)` + `Section` structure.
- Match the existing row pattern: `HStack(spacing: 12)`, leading label, aligned control, and `.roundedBorder` for text/number fields.
- Use `Toggle` with a label or descriptive `VStack`, not a manually reconstructed label/control row.
- Put multi-line editors in a labeled leading `VStack`, with padding, minimum height, and a rounded border.
- Put the primary save button and status feedback in one `HStack`; use `.borderedProminent` for the save action.
- Route every visible string through localization and update both `en.lproj` and `zh-Hans.lproj`.
- Keep editing local state and persist on an explicit save action; never write Keychain or call a network service for every keystroke.

## Verification

After UI changes, run `swift test`. When the change affects app resources or lifecycle, run `./script/build_and_run.sh --verify` if the environment permits launching the app. Check the result in both languages when possible.
