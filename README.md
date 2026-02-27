# BubbleAnnotate

A native macOS app for adding speech bubbles and arrows to videos. Built with SwiftUI and AVFoundation.

![BubbleAnnotate](screenshots/bubble-annotate-main.png)

## Features

- **Speech Bubbles** — Add text bubbles with customisable fonts, colours, borders, corner radius, and opacity
- **Arrows** — Add directional arrows with adjustable thickness, colour, dash style, and arrowhead size
- **Timeline Editor** — Drag, resize, and position annotations on a visual timeline
- **Drag & Resize** — Move and resize all annotations directly on the video overlay
- **Export** — Render annotated videos with all overlays baked in
- **Project Files** — Save and reopen projects to continue editing later
- **Keyboard Shortcuts** — Full keyboard shortcut support for fast workflows

## Download

Download the latest release from the [Releases](https://github.com/urlcv/BubbleAnnotate/releases) page.

- **BubbleAnnotate-1.0-macOS.dmg** — Disk image (mount and drag to Applications)
- **BubbleAnnotate-1.0-macOS.zip** — Compressed archive

### Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

### First Launch

BubbleAnnotate is open-source software distributed outside the Mac App Store. macOS will show a security warning the first time you open it. This is normal — follow the steps below for your macOS version.

#### macOS Sequoia (15.0+)

1. Double-click the app — macOS will show **"BubbleAnnotate" Not Opened**. Click **Done**
2. Open **System Settings** → **Privacy & Security**
3. Scroll down to the **Security** section — you'll see *"BubbleAnnotate" was blocked*
4. Click **Open Anyway** and enter your password
5. The app will launch. You won't be asked again

#### macOS Sonoma (14.0)

1. **Right-click** (or Control-click) `BubbleAnnotate.app` in Finder
2. Select **Open** from the context menu
3. A dialog appears — click **Open**
4. The app will launch. You won't be asked again

#### Alternative: Terminal

If the above doesn't work, open Terminal and run:

```
xattr -cr /Applications/BubbleAnnotate.app
```

Then double-click the app as normal. This removes the download quarantine flag.

> **Why does this happen?** macOS requires apps to be signed with a paid Apple Developer ID ($99/year). BubbleAnnotate is free and open-source, so it isn't signed. The app is safe — you can [review the source code](https://github.com/urlcv/BubbleAnnotate) yourself.

## Usage

1. Launch the app and click **Import Video** or **Open Project**
2. Use the toolbar buttons or keyboard shortcuts to add bubbles and arrows
3. Double-click a bubble on the video to edit its text, press Return to confirm
4. Drag annotations on the video overlay to reposition them
5. Use the timeline to adjust when annotations appear and for how long
6. Click **Export** to render the final video

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘I | Import video |
| ⌘O | Open project |
| ⌘S | Save project |
| ⌘E | Export video |
| ⌘B | Add bubble |
| ⇧⌘A | Add arrow |
| Space | Play / Pause |
| ⌘← | Step back |
| ⌘→ | Step forward |
| Delete | Remove selected annotation |
| + / - | Zoom timeline in/out |

## Building from Source

1. Clone the repository
2. Open `BubbleAnnotate.xcodeproj` in Xcode 15+
3. Build and run (⌘R)

No external dependencies required.

## License

Copyright © 2025 URLCV. All rights reserved.

---

A tool by [URLCV](https://urlcv.com)
