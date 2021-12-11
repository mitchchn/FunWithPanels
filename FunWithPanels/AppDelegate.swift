//
//  AppDelegate.swift
//  FunWithPanels
//
//  Created by Mitchell Cohen on 2021-12-03.
//

import Cocoa

private var methodsSwizzled = false

private var NonActivatingHandle = 0xBADA55
class NonactivatingWindow: NSWindow {
    override var styleMask: NSWindow.StyleMask {
        get {
            [.fullSizeContentView, .nonactivatingPanel]
        }
        set {
            super.styleMask = newValue
        }
    }

    override var collectionBehavior: NSWindow.CollectionBehavior {
        get {
            [.fullScreenAuxiliary, .canJoinAllSpaces]
        }
        set {
            super.collectionBehavior = newValue
        }
    }

    override var canBecomeKey: Bool {
        true
    }
}

extension NSWindow {
    @objc var nonActivatingStyleMask: NSWindow.StyleMask {
        if let _ = objc_getAssociatedObject(self, &NonActivatingHandle) {
            return [.fullSizeContentView, .nonactivatingPanel]
        } else {
            return self.nonActivatingStyleMask
        }
    }

    @objc var nonActivatingCollectionBehavior: NSWindow.CollectionBehavior {
        if let _ = objc_getAssociatedObject(self, &NonActivatingHandle) {
            return [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            return self.nonActivatingCollectionBehavior
        }
    }

    @objc var nonActivatingCanBecomeKey: Bool {
        if let _ = objc_getAssociatedObject(self, &NonActivatingHandle) {
            return true
        } else {
            return self.nonActivatingCanBecomeKey
        }
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet var panel: NSPanel!
    @IBOutlet var window: NSWindow!

    @IBOutlet var windowType: NSPopUpButton!
    @IBOutlet var shouldRemoveTitlebar: NSButton!
    @IBOutlet var panelDelay: NSTextField!
    @IBOutlet var panelCreate: NSButton!
    @IBOutlet var shouldSetPreventsActivation: NSButton!
    @IBOutlet var swizzleType: NSPopUpButton!
    @IBOutlet var shouldTransformProcessType: NSButton!

    @IBAction func createPanel(_ sender: NSButtonCell) {
        let seconds: Double = panelDelay.doubleValue
        let when = DispatchTime.now() + seconds

        sender.isEnabled = false

        resetWindow()

        DispatchQueue.main.asyncAfter(deadline: when) {
            if self.shouldRemoveTitlebar.state == .on {
                if self.windowType.indexOfSelectedItem == 0 {
                    self.removeTitle(self.window)
                } else {
                    self.removeTitle(self.panel)
                }
            }

            if self.shouldTransformProcessType.state == .on {
                self.transformProcessType()
            }

            switch self.swizzleType.indexOfSelectedItem {
            case 0:
                break
            case 1:
                self.swizzleMethods()
                methodsSwizzled = true
            case 2:
                self.swizzleClass()
            default:
                break
            }

            if self.shouldSetPreventsActivation.state == .on {
                self.preventActivation()
            }

            if self.windowType.indexOfSelectedItem == 0 {
                self.window.makeKeyAndOrderFront(nil)
            } else {
                self.panel.makeKeyAndOrderFront(nil)
            }

            sender.isEnabled = true
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        window.center()
        panel.center()

        window.level = .floating
        panel.level = .floating

        // For method swizzling
        objc_setAssociatedObject(window, &NonActivatingHandle, true, .OBJC_ASSOCIATION_COPY)
    }

    func preventActivation() {
        window._setPreventsActivation(true)
    }

    func transformProcessType() {
        var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
        TransformProcessType(&psn, ProcessApplicationTransformState(kProcessTransformToUIElementApplication))
    }

    func swizzleClass() {
        object_setClass(window, NonactivatingWindow.self)
    }

    func swizzleMethods() {
        let styleMaskOriginal = class_getInstanceMethod(NSWindow.self, #selector(getter: NSWindow.styleMask))
        let styleMaskNew = class_getInstanceMethod(NSWindow.self, #selector(getter: NSWindow.nonActivatingStyleMask))
        method_exchangeImplementations(styleMaskOriginal!, styleMaskNew!)

        let canBecomeKeyOriginal = class_getInstanceMethod(NSWindow.self, #selector(getter: NSWindow.canBecomeKey))
        let canBecomeKeyNew = class_getInstanceMethod(NSWindow.self, #selector(getter: NSWindow.nonActivatingCanBecomeKey))
        method_exchangeImplementations(canBecomeKeyOriginal!, canBecomeKeyNew!)

        let collectionBehaviorOriginal = class_getInstanceMethod(NSWindow.self, #selector(getter: NSWindow.collectionBehavior))
        let collectionBehaviorNew = class_getInstanceMethod(NSWindow.self, #selector(getter: NSWindow.nonActivatingCollectionBehavior))
        method_exchangeImplementations(collectionBehaviorOriginal!, collectionBehaviorNew!)
    }

    func removeTitle(_ window: NSWindow) {
        window.styleMask.remove(.titled)

        // Reconstruct the round rect border
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView?.wantsLayer = true
        window.contentView?.layer!.backgroundColor = NSColor.windowBackgroundColor.cgColor
        window.contentView!.layer!.cornerRadius = 10.0
        window.isMovableByWindowBackground = true
    }

    func restoreTitle(_ window: NSWindow) {
        window.styleMask.insert(.titled)
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isMovableByWindowBackground = false
    }

    func resetWindow() {
        window.orderOut(nil)
        panel.orderOut(nil)

        // Unswizzle class
        object_setClass(window, NSWindow.self)

        // Reverse method swizzle
        if methodsSwizzled {
            swizzleMethods()
            methodsSwizzled = false
        }

        // Unset nonActivating
        window._setPreventsActivation(false)

        // Reset process type
        var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
        TransformProcessType(&psn, ProcessApplicationTransformState(kProcessTransformToForegroundApplication))

        // Restore the title
        restoreTitle(window)
        restoreTitle(panel)
    }

    func applicationWillTerminate(_: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        return true
    }
}
