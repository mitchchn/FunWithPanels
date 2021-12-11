//
//  AppDelegate.swift
//  FunWithPanels
//
//  Created by Mitchell Cohen on 2021-12-03.
//

/// The goal: convert a non-panel window into something that looks and works like NSPanel.
/// To make things more interesting, the app has a separate, normal, activating window.
/// Four solutions are included with different respective trade-offs. A real NSPanel is also included
/// for comparison.
///
/// ## 1. `NSWindow._setsNonActivating`
///
/// The simplest fix is to use a private API to make the window non-activating.
/// Unfortunately this is not an option on the App Store.
///
///
/// ## 2 Transform the process type
///
/// This makes the entire app non-activating, but it comes at the cost of losing
/// the Dock icon and menubar. It would be a suitable solution if the panel had its own
/// process or only ran when other app windows were closed and the Dock icon was hidden.
///
///
/// ## 3. Swizzle to `NonactivatingWindow`
///
/// `StyleMask.nonActivatingPanel` cannot be set on NSWindow, but this restriction can
/// be circumvented by casting the window to our own class which overrides the `styleMask` property.
/// This subclass will also override any properties needed to achieve panel behavior. The resulting window
/// cannot be activated -- well, almost. There is still one weak spot.
///
/// ## 4. Swizzle + remove the titlebar
///
/// `NonactivatingWindow` works well, but the window can still be activated if you click near the top
/// on the invisible titlebar. This is not the end of the world, but we can make the solution more complete
/// by removing the titlebar completely. This finally gives us a window that cannot be activated at all.
/// The big caveat is that removing the titlebar also removes the window borders, and even though we can
/// reconstruct them, they won't look exactly the same as a default NSPanel. However, this is exactly what
/// Alfred does, so I call it a win.

import Cocoa

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
            [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        set {
            super.collectionBehavior = newValue
        }
    }

    override var isFloatingPanel: Bool {
        true
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override var canHide: Bool {
        get {
            false
        }
        set {
            super.canHide = newValue
        }
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var panel: NSPanel!
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var panelLabel: NSTextField!
    
    @IBOutlet weak var windowTitlebarLabel: NSTextField!
    @IBOutlet weak var panelTitlebarLabel: NSTextField!
    
    @IBOutlet weak var panelType: NSPopUpButton!
    @IBOutlet weak var panelRemoveTitlebar: NSButton!
    @IBOutlet weak var panelDelay: NSTextField!
    @IBOutlet weak var panelCreate: NSButton!
    
    
    @IBAction func createPanel(_ sender: NSButtonCell) {
        let seconds: Double = panelDelay.doubleValue
        let when = DispatchTime.now() + seconds
        
        sender.isEnabled = false
        
        self.resetWindow()
        

        if panelRemoveTitlebar.state == .on {
            if self.panelType.selectedTag() == 0 {
                self.removeTitle(panel)
                self.panelTitlebarLabel.isHidden = true
            } else {
                self.removeTitle(window)
                self.windowTitlebarLabel.isHidden = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: when) {
            switch self.panelType.selectedTag() {
            case 0:
                self.showNSPanel()
            case 1:
                self.preventActivation()
            case 2:
                self.transformProcessType()
            case 3:
                self.makeNonactivatingWindow()
            default:
                break
            }
            sender.isEnabled = true
        }
    }
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window.center()
        panel.center()



        window.level = .floating
        panel.level = .floating
    }
    
    func showNSPanel() {
        panel.makeKeyAndOrderFront(nil)
    }
    
    func preventActivation() {
        window._setPreventsActivation(true)
        panelLabel.stringValue = "Window used _setPreventsActivation."
        window.makeKeyAndOrderFront(nil)
    }
    
    func transformProcessType() {
        var psn = ProcessSerialNumber.init(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess ))
        TransformProcessType(&psn, ProcessApplicationTransformState(kProcessTransformToUIElementApplication))
        
        panelLabel.stringValue = "App used TransformProcessType."
        window.makeKeyAndOrderFront(nil)
    }
    
    func makeNonactivatingWindow() {
        panelLabel.stringValue = "Swizzle to "
        object_setClass(window, NonactivatingWindow.self)
        
        panelLabel.stringValue = "Window was swizzled to NonactivatingWindow."

        window.makeKeyAndOrderFront(nil)
    }
    
    
    func removeTitle(_ window: NSWindow) {
        window.styleMask.remove(.titled)

        // Reconstruct the round rect border
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView?.wantsLayer = true
        window.contentView?.layer!.backgroundColor =  NSColor.windowBackgroundColor.cgColor
        window.contentView!.layer!.cornerRadius    = 10.0
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
        
        // Unswizzle
        object_setClass(window, NSWindow.self)
        
        // Unset nonActivating
        window._setPreventsActivation(false)
        
        // Reset process type
        var psn = ProcessSerialNumber.init(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess ))
        TransformProcessType(&psn, ProcessApplicationTransformState(kProcessTransformToForegroundApplication))

        // Restore the title
        self.restoreTitle(window)
        self.restoreTitle(panel)
        
        self.windowTitlebarLabel.isHidden = false
        self.panelTitlebarLabel.isHidden = false


    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

