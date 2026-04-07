import SwiftUI
import AppKit
import CoreGraphics
import ApplicationServices

// MARK: - Shared State
// Allows AppKit to update variables and SwiftUI to animate the changes natively.
@MainActor
class AppState: ObservableObject {
    @Published var searchQuery = ""
    @Published var isSearchSelected = false
    @Published var filteredEmojis: [EmojiDef] = []
    @Published var selectedIndex = 0
    // Changing this UUID triggers the SwiftUI view to reset its scroll position
    @Published var resetScrollTrigger = UUID()
    let columnsCount = 6
}

// MARK: - Panel
class FlamojiPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
}

@main
@MainActor
struct EmojiPopupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { Text("Settings") } }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FlamojiPanel!
    var localEventMonitor: Any?
    var eventTap: CFMachPort?
    var targetApp: NSRunningApplication?
    
    let appState = AppState()
    var isShowing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupPanel()
        setupGlobalHotkey()
        print("Flamoji is running! Press Cmd + Option + E to trigger.")
    }

    func setupPanel() {
        panel = FlamojiPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 270), 
            styleMask: [.borderless, .nonactivatingPanel], 
            backing: .buffered, defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        
        let contentView = EmojiPickerView(state: appState)
        panel.contentView = NSHostingView(rootView: contentView)
        
        NotificationCenter.default.addObserver(self, selector: #selector(panelLostFocus), name: NSWindow.didResignKeyNotification, object: panel)
    }

    @objc func panelLostFocus() { hidePopup() }

    func setupGlobalHotkey() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .keyDown {
                    let flags = event.flags
                    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
                    if flags.contains(.maskCommand) && flags.contains(.maskAlternate) && keycode == 14 {
                        let mySelf = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                        DispatchQueue.main.async { mySelf.togglePopup() }
                        return nil 
                    }
                }
                return Unmanaged.passRetained(event)
            }, userInfo: userInfo
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
        if !isShowing { targetApp = NSWorkspace.shared.frontmostApplication }
        
        isShowing = true
        appState.searchQuery = ""
        appState.isSearchSelected = false
        appState.filteredEmojis = EmojiManager.shared.allEmojis
        appState.selectedIndex = 0
        appState.resetScrollTrigger = UUID()
        
        let panelWidth: CGFloat = 280.0
        let panelHeight: CGFloat = 270.0
        
        // 1. Get the best possible screen reference safely
        let mouseLoc = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let currentScreen = screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main ?? screens.first
        
        // 2. Fallback to a default size if for some reason NO screen is detected
        let screenFrame = currentScreen?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let visibleFrame = currentScreen?.visibleFrame ?? screenFrame
        
        var targetPoint: CGPoint = .zero
        
        if let caretPos = getCaretPosition() {
            // Convert Accessibility (Top-Left) to AppKit (Bottom-Left)
            targetPoint = CGPoint(
                x: caretPos.x - 16, 
                y: screenFrame.height - caretPos.y - panelHeight - 30
            )
        } else {
            // Fallback to mouse position if caret isn't found
            targetPoint = CGPoint(
                x: mouseLoc.x + 10, 
                y: mouseLoc.y - panelHeight
            )
        }
        
        // 3. Smart Clamping (Prevent Overflow)
        // Ensure the panel stays within the horizontal visible bounds
        let minX = visibleFrame.origin.x + 10
        let maxX = visibleFrame.origin.x + visibleFrame.width - panelWidth - 10
        targetPoint.x = max(minX, min(targetPoint.x, maxX))
        
        // Ensure the panel stays within the vertical visible bounds (Dock/Menu Bar aware)
        let minY = visibleFrame.origin.y + 10
        let maxY = visibleFrame.origin.y + visibleFrame.height - panelHeight - 10
        targetPoint.y = max(minY, min(targetPoint.y, maxY))
        
        // 4. Set position and show
        panel.setFrameOrigin(targetPoint)
        panel.makeKeyAndOrderFront(nil)
        
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyPress(event)
                return nil
            }
        }
    }

    func hidePopup() {
        isShowing = false
        panel.orderOut(nil)
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    func getCaretPosition() -> CGPoint? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else { return nil }
        let element = focusedElement as! AXUIElement
        
        var selectedRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success else { return nil }
        
        var bounds: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, selectedRange!, &bounds) == .success else { return nil }
        
        let boundsValue = bounds as! AXValue
        var rect: CGRect = .zero
        AXValueGetValue(boundsValue, .cgRect, &rect)
        if rect.origin.x == 0 && rect.origin.y == 0 { return nil }
        return CGPoint(x: rect.origin.x, y: rect.origin.y)
    }

    func handleKeyPress(_ event: NSEvent) {
        let isModifierPressed = event.modifierFlags.intersection([.command, .control]).isEmpty == false
        if isModifierPressed {
            if event.keyCode == 0 { // 'A' key
                if !appState.searchQuery.isEmpty { appState.isSearchSelected = true }
            } else if event.keyCode == 51 { // Backspace
                appState.searchQuery = ""
                appState.isSearchSelected = false
                updateSearch()
            }
            return
        }
        
        switch event.keyCode {
        case 53: // esc
            hidePopup()
        case 123: // Left arrow
            if appState.selectedIndex > 0 { appState.selectedIndex -= 1 }
        case 124: // Right arrow
            if appState.selectedIndex < appState.filteredEmojis.count - 1 { appState.selectedIndex += 1 }
        case 125: // Down arrow
            if appState.selectedIndex + appState.columnsCount < appState.filteredEmojis.count {
                appState.selectedIndex += appState.columnsCount
            } else {
                appState.selectedIndex = max(0, appState.filteredEmojis.count - 1)
            }
        case 126: // Up arrow
            if appState.selectedIndex - appState.columnsCount >= 0 {
                appState.selectedIndex -= appState.columnsCount
            } else {
                appState.selectedIndex = 0 
            }
        case 36: // Enter
            if !appState.filteredEmojis.isEmpty {
                insertEmoji(appState.filteredEmojis[appState.selectedIndex].symbol)
            }
        case 51: // Backspace
            if appState.isSearchSelected {
                appState.searchQuery = ""
                appState.isSearchSelected = false
                updateSearch()
            } else if !appState.searchQuery.isEmpty {
                appState.searchQuery.removeLast()
                updateSearch()
            }
        default:
            if let chars = event.charactersIgnoringModifiers {
                let printable = chars.filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
                if !printable.isEmpty {
                    if appState.isSearchSelected {
                        appState.searchQuery = ""
                        appState.isSearchSelected = false
                    }
                    appState.searchQuery += printable
                    updateSearch()
                }
            }
        }
    }
    
    func updateSearch() {
        appState.filteredEmojis = EmojiManager.shared.search(query: appState.searchQuery)
        appState.selectedIndex = 0 
    }

    func insertEmoji(_ emoji: String) {
        guard let app = targetApp else { return }
        
        // Permanently record that this emoji was used
        EmojiManager.shared.recordUsage(symbol: emoji)
        
        let source = CGEventSource(stateID: .hidSystemState)
        let utf16Chars = Array(emoji.utf16)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        keyDown?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        keyUp?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        
        keyDown?.postToPid(app.processIdentifier)
        keyUp?.postToPid(app.processIdentifier)
    }
}
