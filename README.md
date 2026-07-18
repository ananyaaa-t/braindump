# Braindump

A personal, mobile notes app for iOS. An aesthetic take on the Apple Notes
app for people who want more organization than the default app but less than
Notion — a flat list of "pages," each with its own solid pastel background
color, no folders, no nested pages, no block-based editor. Closer to a stack
of colored notecards than a productivity tool.

## Stack

- **Swift + SwiftUI** — all UI
- **SwiftData** (iOS 17+) — local persistence, no backend/auth/sync
- **NavigationStack** — list → page navigation
- A custom `UITextView`-based rich-text editor (`RichTextEditor.swift`),
  bridged into SwiftUI, for reliable native typing/Enter/Backspace behavior
  that SwiftUI's `TextField` couldn't provide
- **WidgetKit** + App Groups — home screen widget sharing data with the app

## Features

- Create, list, open/edit, and delete pages
- Change a page's pastel color
- Rich text: headings/subheading/body styles, bullets, checklists
- Character-level Bold/Italic/Underline formatting
- Soft-delete with a 30-day "recently deleted" recovery flow
- Home screen widget for quick access to a chosen page
- Full VoiceOver accessibility support
