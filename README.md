# Flamoji (Flash Emoji) 🔥

A blazing fast, invisible, and fully native macOS emoji picker designed for power users. No animations.

**Note: This entire project was 100% vibe coded.** Flamoji runs silently in the background and intercepts your keystrokes globally, allowing you to inject emojis directly into any application (including Electron apps like VS Code and Chrome) without ever losing keyboard focus or dealing with UI flicker.

## ✨ Features

* **Lightning Fast:** Built natively with AppKit and SwiftUI.
* **Ghost Mode UI:** Acts as a non-activating Key Window. It never steals focus from the app you are currently typing in.
* **Usage-Based Sorting:** Learns which emojis you use the most and floats them to the top of the grid using persistent `UserDefaults`.
* **Semantic Tag Search:** Bundled with over 4,000+ emojis and hundreds of thousands of keywords for instant filtering.
* **Arrow Keys Friendly:** You can use arrow keys to select emojis. (This works well with my other project [mokr](https://github.com/zetcco/mokr), which lets you use arrow keys using CapsLock + VIM motions).

---

## 🏗 Architecture 

Building a seamless overlay on macOS requires bypassing several standard OS behaviors. Flamoji relies on four core pillars:

1. **`CGEventTap` (Global Keystroke Interception & Injection):** Instead of using standard global monitors, we hook directly into the CoreGraphics hardware event stream. This allows us to listen for our hotkey (`Cmd + Option + E`) while the app is in the background, and more importantly, allows us to use `postToPid()` to inject UTF-16 emoji characters directly into the target app's memory process without dropping keyboard focus.
2. **`AXUIElement` (Caret Tracking):** Flamoji queries the macOS Accessibility API to find the exact screen pixel coordinates of the text caret. 
   * *Native Apps:* Uses `kAXSelectedTextRangeAttribute`.
   * *Chromium/Electron Apps:* Uses an undocumented WebKit heuristic (`AXSelectedTextMarkerRange`).
   * *Fallback:* If the app disables accessibility, Flamoji calculates the `kAXPositionAttribute` and `kAXSizeAttribute` to gracefully center itself in the active window.
3. **Non-Activating Key Window (`NSPanel`):** By overriding `canBecomeKey` to `true` on an `NSPanel` with the `.nonactivatingPanel` style mask, Flamoji achieves "Ghost Mode." It can accept typing input for the search bar without the underlying application (or the macOS Menu Bar) ever realizing it lost focus.
4. **SwiftUI & `ObservableObject`:** The UI is purely SwiftUI, backed by an `@MainActor` state class. This allows seamless state updates, dynamic filtering, and programmatic `ScrollViewReader` jumps without re-rendering the AppKit hosting controller.

---

## ⚠️ Known Limitations (The Chromium Quirk)

Because macOS does not expose native input methods to background apps, Flamoji relies on the macOS Accessibility API to find your blinking text cursor. 

* **Native Apps (Safari, Notes, Xcode):** Flamoji will track your cursor pixel-perfectly and pop up right next to the text.
* **Chromium/Web Apps (Chrome, Arc, etc.):** Google's rendering engine aggressively lazy-loads its accessibility tree to save RAM. Because it often refuses to tell macOS where the text caret is, **Flamoji will gracefully fall back to opening in the exact center of your active browser window or where the mouse cursor is.**

---

## 🚀 Installation & Build

Flamoji is built using the Swift Package Manager (SPM) and wrapped with a standard Makefile. It is designed to run as a stealth UNIX binary (because you might be under MDM, like me 🥲), bypassing standard `.app` structures. Xcode is not required.

### Prerequisites
* macOS 13.0 or higher
* Swift command-line tools installed (`xcode-select --install`)

### Compile & Install
1. **Clone the repository:**
   ```bash
   git clone [https://github.com/zetcco/flamoji.git](https://github.com/zetcco/flamoji.git)
   cd flamoji
   ```

2. **Build and Stash the Binary:**
   Run the install command. This will automatically download the `emojilib` JSON dictionary, compile the Swift binary in release mode, and stash it in a hidden directory (`~/.flamoji/`).
   ```bash
   make install
   ```

3. **Run it:**
   Start the background process for your current session:
   ```bash
   make start
   ```

*Note: Because Flamoji is launched via the command line, macOS requires you to grant **Accessibility permissions to your Terminal app** (e.g., Terminal, iTerm2, Kitty) in `System Settings > Privacy & Security > Accessibility` to allow keystroke injection.*

## ⌨️ Usage

* **Trigger:** Press `Cmd + Option + E` anywhere on your Mac to open the panel.
* **Navigate:** Use the arrow keys (or your mapped HJKL keys) to move the selection.
* **Search:** Just start typing! The search bar automatically captures your keystrokes. Use `Ctrl+A` or `Cmd+A` to highlight the text to quickly overwrite it.
* **Insert:** Press `Enter` to inject the emoji. 
* **Close:** Press `Esc`, click anywhere else on your screen, or switch windows to cleanly dismiss the app.

---

## 🛑 Stop & Clean
If you want to kill the background process:
```bash
make stop
```

If you are developing and need to wipe the build artifacts and the installed binary:
```bash
make clean
```
