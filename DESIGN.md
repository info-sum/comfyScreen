# ScreenshotRouter MVP Design

## Product contract

ScreenshotRouter is a lightweight macOS menu-bar app. It leaves the system `Command+Shift+4` behavior unchanged. When macOS writes a new screenshot into its configured capture directory, the app moves that file into its own temporary staging directory, brings a compact routing window forward, and asks where to save it.

The common path is one decision and one action: press `Command+Shift+4` to begin an area capture, inspect the preview, select a destination, then press `Command+S` or click **Save**. Every capture is copied to the clipboard for immediate pasting. `Command+1` through `Command+9` route immediately to the corresponding destination.

## Native form

- Swift Package executable named `ScreenshotRouter`, targeting macOS 14 or newer.
- SwiftUI for the menu-bar item, routing window, and settings window; AppKit only where SwiftUI lacks window activation, folder picking, and file-system coordination.
- No third-party dependencies, Xcode project generator, persistence framework, or custom design system.
- A packaging script may assemble the release executable and `Info.plist` into `ScreenshotRouter.app`; the package must still build with `swift build -c release` using CommandLineTools alone.

## Runtime flow

1. Resolve the source directory from `SCREENSHOT_ROUTER_WATCH_DIR` when present (QA only), otherwise from `defaults read com.apple.screencapture location`, falling back to `~/Desktop`.
2. Record the initial directory contents so existing images are never treated as new captures.
3. Observe directory writes with a `DispatchSourceFileSystemObject` and rescan after events.
4. Accept newly created regular `.png`, `.jpg`, or `.jpeg` files whose names match the localized macOS screenshot prefixes `Screenshot` or `스크린샷`. Ignore hidden, partial, unrelated, and pre-existing files.
5. Wait until size and modification time are stable across two short probes, then atomically move the capture into `~/Library/Caches/ScreenshotRouter/Pending` using a collision-safe filename.
6. Queue captures serially. Present the oldest pending capture; never duplicate a file already seen or staged.
7. On save, copy/move the pending file into the selected destination with a collision-safe filename, remove the staged file only after the destination write succeeds, show concise success feedback, then show the next item or close the routing window.
8. On failure, keep the staged file and show a recoverable error. Never delete user data on an unsuccessful operation.

## Interface

### Menu bar

- System symbol: `camera.viewfinder`.
- Items: **Open Router**, **Destinations…**, capture-directory status, **Quit**.

### Routing window

- Calm, compact `main-with-rail` window, minimum 760×480. The preview is the dominant region and the destination rail is the narrow supporting region; neither region owns a nested scroll unless destination count requires it.
- Left: aspect-fit screenshot preview in a dark, concentric media well so light screenshots remain distinct from the window.
- Right: one elevated glass surface containing **Save screenshot**, an editable file name, status, and destination actions.
- The file name field is prefilled with `스크린샷_yyyy-MM-dd_HH-mm-ss` from the capture time and shows the fixed extension beside it. It is not focused when a capture arrives, so ⌘C copies the image; clicking it edits the name. An empty name saves with the default; `/` and `:` become `-`, leading dots are dropped, and overlong names are shortened to fit.
- Each destination row shows its friendly name, abbreviated path, and shortcut badge `⌘1`…`⌘9`; clicking a row saves immediately.
- Selection changes immediately; the Save button is disabled when no writable destination exists.
- Keyboard: Up/Down changes selection, Return and Command+S save to the selection, Escape hides the window without discarding the pending file, Command+1…9 saves directly, Command+C copies the capture image unless the name is being edited.
- Use native materials, system typography, semantic colors, clear VoiceOver labels, and no decorative animation. Feedback is immediate and predictable.

### First launch

- On the first normal launch, open a setup surface before the routing window. It lets the user select one or more destination folders and review the two optional system permissions used by area capture.
- The setup surface keeps the destination order visible with a right-aligned `⌘1`…`⌘9` badge, matching the immediate-save shortcuts used after a capture.
- The setup surface explains the purpose of **Screen Recording** and **Accessibility** in plain language. A system request happens only after the user activates the matching **Request permission** control; it is never shown automatically at launch.
- A user can complete setup once at least one writable destination exists, even if they defer a permission. Settings retains both the destination controls and live permission status so the choice is always reversible.

### Visual system

- **Direction:** quiet optical glass. Screenshot content carries the color; chrome stays neutral and recedes.
- **Material:** on macOS 26+, use native regular Liquid Glass for the navigation capsule and destination/settings surfaces. On macOS 14–15, use `regularMaterial` with the same geometry. Do not add a third-party glass dependency.
- **Surface hierarchy:** window canvas → dark preview well → glass utility surface → tonal destination rows. Never stack translucent material on another translucent material.
- **Color roles:** semantic system colors only. Accent color is reserved for the selected tab, actionable save icon, and keyboard focus. Errors use the system destructive color.
- **Geometry:** 24pt window content inset, 20pt major surface radius, 14pt destination row radius, capsule navigation controls, 8pt base spacing.
- **Depth:** one soft ambient shadow on floating utility surfaces plus a low-opacity white rim; no colored borders or decorative glow.
- **Typography:** San Francisco system text. Headlines use title weight, filenames and paths use secondary/monospaced treatments only where truncation needs clarity.
- **Motion:** native press feedback only. No looping, entrance, parallax, or decorative motion.

### Reusable visual primitives

- `GlassSurface`: adaptive Liquid Glass/material container with solid fallback when Reduce Transparency is enabled.
- `PreviewWell`: aspect-fit media frame with a neutral dark backing and concentric corner radius.
- `DestinationRow`: one-click save action with name, abbreviated path, shortcut, disabled state, and VoiceOver label.
- `RouterNavigation`: compact save/settings capsule that preserves reading and keyboard order.
- `SetupChecklist`: first-launch setup surface with destination selection, explicit system-permission requests, textual status, and a continue action.

### Accessibility constraints

- Respect Reduce Transparency with an opaque semantic system background.
- Keep text and symbols semantic so contrast adapts in light and dark appearances.
- Preserve a visible keyboard focus ring and minimum 28pt pointer targets.
- Do not communicate destination availability through color alone; disabled rows also reduce emphasis and expose disabled semantics.
- Long filenames and paths truncate in the middle or tail without widening the rail.
- Permission prompts are explicitly initiated by the user, and their status is expressed by both an SF Symbol and text.

### Accepted design debt

- Native Liquid Glass appearance is available only on macOS 26+. macOS 14–15 intentionally use system material rather than a visual imitation.

### Destination settings

- Ordered list with **Add Folder…**, **Remove**, **Move Up**, and **Move Down**.
- Folder picker supplies the friendly name from `lastPathComponent`; duplicate canonical paths are rejected.
- Persist destination path and order in `UserDefaults`. Because the MVP is not sandboxed, plain paths are sufficient; explain that moved/deleted or protected folders must be reselected.
- Empty state tells the user to add a destination before routing.

## File and state model

- `Destination`: stable UUID, display name, standardized path.
- `PendingCapture`: staged URL plus original filename and discovery date.
- One observable app model owns destination persistence, pending queue, selection, save errors, and window requests.
- One watcher owns only discovery/stability/staging and emits staged URLs to the app model.
- Avoid protocols, repositories, coordinators, factories, or services with one implementation.

## Safety and lifecycle

- Never process files that existed before launch.
- Never overwrite a destination file; append ` 2`, ` 3`, and so on.
- Failed saves retain the staged original.
- On relaunch, recover files already present in the Pending directory.
- Quit leaves pending files recoverable in the cache and explains this in the menu/settings copy.
- The app does not require Accessibility permission because it does not intercept global shortcuts or synthesize input.

## Verification seam

- `SCREENSHOT_ROUTER_WATCH_DIR` overrides only the watched source for isolated QA.
- `SCREENSHOT_ROUTER_DESTINATIONS` may contain colon-separated destination paths for an isolated QA launch; when set, it seeds the in-memory destination list without overwriting normal UserDefaults.
- These environment variables are not exposed in the user interface.
