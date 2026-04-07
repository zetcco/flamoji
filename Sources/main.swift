import SwiftUI
import AppKit
import CoreGraphics
import ApplicationServices

// MARK: - Panel
// Custom panel forces macOS to let us intercept keyboard events 
// It does not become active, so the app never steals focus from the target application (where emojis should pop up)
class FlamojiPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

@main
@MainActor
struct EmojiPopupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Not actually using this window, but swiftui requires a scene
        Settings {
            Text("Emoji Popup Settings")
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FlamojiPanel!
    
    // intercepts local keys (like arrows/enter) only while the panel is visible
    var localEventMonitor: Any?
    
    // holds the low-level global tap that listens for Cmd+Option+E in the background
    var eventTap: CFMachPort?
    
    // The app which will recieve the emoji insertion (the one currently in the foreground when the hotkey is triggered)
    var targetApp: NSRunningApplication?
    var isInserting = false
    
    // hardcoded emoji list for demo purposes, can be expanded or made dynamic later
    let emojis = [
        "😀", "😂", "🥰", "😎", "🤔", "🙌", "🔥", "✨",
        "🎉", "🚀", "💡", "👀", "💯", "🙏", "❤️", "🤷‍♂️",
        "😭", "💀", "👍", "👎", "✅", "❌", "🎨", "💻"
    ]
    let columnsCount = 6 

    var selectedIndex = 0
    var isShowing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // hide the app from the dock entirely
        NSApp.setActivationPolicy(.accessory)
        
        setupPanel()
        setupGlobalHotkey()
        print("Flamoji is running smoothly! Press Cmd + Option + E to trigger.")
    }

    // MARK: - Window Setup
    func setupPanel() {
        panel = FlamojiPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            // Bring BACK .nonactivatingPanel so it acts as an overlay
            styleMask: [.borderless, .nonactivatingPanel], 
            backing: .buffered,
            defer: false
        )
        
        // make it float above everything else
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        
        // allows the panel to follow you if you swipe across virtual desktop spaces
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        
        updateUI()
        
        // Listen for when the specific window loses keyboard focus (e.g. clicking away)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelLostFocus),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
    }
    
    func updateUI() {
        // wrap the pure swiftui view inside an appkit hosting view
        let contentView = EmojiPickerView(
            emojis: emojis,
            selectedIndex: selectedIndex,
            columnsCount: columnsCount
        )
        panel.contentView = NSHostingView(rootView: contentView)
    }

    @objc func panelLostFocus() {
        hidePopup()
    }

    // MARK: - Add global hotkey listener using CGEventTap (more reliable than NSEvent global monitors)
    // Cmd + Option + E to trigger the popup
    func setupGlobalHotkey() {
        // considering only when a key is pressed down
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        // this hooks into the OS right at the hardware level before apps even see the keys
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .keyDown {
                    let flags = event.flags
                    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
                    
                    // 14 is the hardware keycode for 'E'
                    if flags.contains(.maskCommand) && flags.contains(.maskAlternate) && keycode == 14 {
                        let mySelf = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                        DispatchQueue.main.async { mySelf.togglePopup() }
                        
                        // return nil to swallow the event so it doesn't actually type an "e"
                        return nil 
                    }
                }
                // let all other keystrokes pass through normally
                return Unmanaged.passRetained(event)
            },
            userInfo: userInfo
        )
        
        guard let tap = eventTap else { return }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func togglePopup() {
        if isShowing { hidePopup() } else { showPopup() }
    }

    func showPopup() {
        if !isShowing {
            // grab the app the user is currently looking at BEFORE opening the emoji panel
            targetApp = NSWorkspace.shared.frontmostApplication
        }
        
        isShowing = true
        selectedIndex = 0
        updateUI()
        
        // attempt to pop up right at the blinking text cursor
        if let caretPos = getCaretPosition() {
            // Accessibility coordinates are top-left origin, but AppKit window coordinates are bottom-left origin.
            // So flip the Y axis using the main display's height.
            let screenHeight = CGDisplayBounds(CGMainDisplayID()).height
            let popupPoint = CGPoint(x: caretPos.x, y: screenHeight - caretPos.y - 220) 
            panel.setFrameOrigin(popupPoint)
        } else {
            // fallback to mouse location if the app (like Chrome or VSCode) is hiding its caret position from macOS
            let mouseLoc = NSEvent.mouseLocation
            panel.setFrameOrigin(CGPoint(x: mouseLoc.x + 10, y: mouseLoc.y - 200))
        }
        
        // Make the panel a target for keyboard events, but does NOT activate the app. Otherwise focus will be stolen by the target app.
        panel.makeKeyAndOrderFront(nil)
        
        // start listening for arrow keys and enter
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyPress(event)
                // swallow the event so the underlying app doesn't scroll when when pressing arrows, etc.
                return nil
            }
        }
    }

    func hidePopup() {
        isShowing = false
        panel.orderOut(nil) // visually hide the window
        
        // clean up 
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    // MARK: - Caret Location Magic
    func getCaretPosition() -> CGPoint? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        
        // 1. grab whatever UI element currently has focus (like a text field)
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else { return nil }
        let element = focusedElement as! AXUIElement
        
        // 2. figure out what text is selected (a blinking cursor is just a selection of length 0)
        var selectedRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success else { return nil }
        
        // 3. ask the OS for the exact screen pixels where that text range is drawn
        var bounds: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, selectedRange!, &bounds) == .success else { return nil }
        
        let boundsValue = bounds as! AXValue
        var rect: CGRect = .zero
        AXValueGetValue(boundsValue, .cgRect, &rect)
        
        // if it reports exactly 0,0 the app is likely lying to the accessibility API (very common in Electron apps)
        if rect.origin.x == 0 && rect.origin.y == 0 { return nil }
        return CGPoint(x: rect.origin.x, y: rect.origin.y)
    }

    // MARK: - Emoji panel naviagtion and insertion
    func handleKeyPress(_ event: NSEvent) {
        switch event.keyCode {
        case 53: // esc
            hidePopup()
        case 123: // Left arrow
            if selectedIndex > 0 { selectedIndex -= 1 }
        case 124: // Right arrow
            if selectedIndex < emojis.count - 1 { selectedIndex += 1 }
        case 125: // Down arrow
            // jump down a full row, but don't go out of bounds
            if selectedIndex + columnsCount < emojis.count {
                selectedIndex += columnsCount
            } else {
                selectedIndex = emojis.count - 1 
            }
        case 126: // Up arrow
            // jump up a full row
            if selectedIndex - columnsCount >= 0 {
                selectedIndex -= columnsCount
            } else {
                selectedIndex = 0 
            }
        case 36: // Enter/Add emoji
            let selectedEmoji = emojis[selectedIndex]
            insertEmoji(selectedEmoji)
        default:
            return
        }
        updateUI() // re-render the swiftui view to move the blue highlight
    }

    func insertEmoji(_ emoji: String) {
        guard let app = targetApp else { return } // return if no target app
        
        // setup the low-level event source to simulate hardware keyboard
        let source = CGEventSource(stateID: .hidSystemState)
        let utf16Chars = Array(emoji.utf16)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        keyDown?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        keyUp?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        
        // instead of posting to the global OS stream (which requires giving up focus),
        // fire the events directly into the target app's specific process.
        keyDown?.postToPid(app.processIdentifier)
        keyUp?.postToPid(app.processIdentifier)
    }
}

// MARK: - SwiftUI View
struct EmojiPickerView: View {
    let emojis: [String]
    let selectedIndex: Int
    let columnsCount: Int
    
    var body: some View {
        // create a grid layout matching the column count
        let columns = Array(repeating: GridItem(.fixed(36), spacing: 4), count: columnsCount)
        
        VStack {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<emojis.count, id: \.self) { index in
                    Text(emojis[index])
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                        // highlight the current index with the user's system accent color (usually blue)
                        .background(index == selectedIndex ? Color.accentColor : Color.clear)
                        .cornerRadius(8)
                }
            }
            .padding(12)
        }
        // apply the native macos frosted glass effect to the background
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .cornerRadius(12)
        // add a subtle border so it doesn't bleed into light backgrounds
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// helper wrapper to bring AppKit's native blur into SwiftUI
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
