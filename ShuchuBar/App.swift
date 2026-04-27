import SwiftUI
import LaunchAtLogin
#if SPARKLE
import Sparkle
#endif

extension NSImage.Name {
    static let idle = Self("BarIconIdle")
}

extension Notification.Name {
    static let tbPopoverDidShow = Notification.Name("TBPopoverDidShow")
}

private enum UIConstants {
    static let buttonCornerRadius: CGFloat = 4
    static let grayBackgroundMaxAlpha: CGFloat = 10.0  // Divider for opacity calculation
}

@main
struct TBApp: App {
    @NSApplicationDelegateAdaptor(TBStatusItem.self) var appDelegate

    init() {
        TBStatusItem.shared = appDelegate
        LaunchAtLogin.migrateIfNeeded()
        logger.append(event: TBLogEventAppStart())
    }

    var body: some Scene {
        Settings {}
    }
}

class TBStatusItem: NSObject, NSApplicationDelegate {
    private var popover = NSPopover()
    var statusBarItem: NSStatusItem?
    static var shared: TBStatusItem!
    private var view: TBPopoverView!
    #if SPARKLE
    private let updaterController: SPUStandardUpdaterController
    private let userDriverDelegate = TBStatusItemUserDriverDelegate()
    #endif

    // Read display settings directly from AppStorage
    @AppStorage("grayBackgroundOpacity") private var grayBackgroundOpacity = Default.grayBackgroundOpacity

    override init() {
        #if SPARKLE
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: userDriverDelegate)
        #endif
        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        view = TBPopoverView()

        popover.behavior = .transient
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: view)
        if let contentViewController = popover.contentViewController {
            popover.contentSize.height = contentViewController.view.intrinsicContentSize.height
            popover.contentSize.width = contentViewController.view.intrinsicContentSize.width
        }

        statusBarItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        statusBarItem?.button?.imagePosition = .imageLeft
        statusBarItem?.button?.wantsLayer = true
        statusBarItem?.button?.layer?.cornerRadius = UIConstants.buttonCornerRadius
        setIcon(name: .idle)
        statusBarItem?.button?.sendAction(on: [.leftMouseUp])
        statusBarItem?.button?.action = #selector(TBStatusItem.handleClick(_:))

        view.timer.updateDisplay()
    }

    @objc func handleClick(_ sender: AnyObject?) {
        let event = NSApp.currentEvent

        switch event?.type {
        case .leftMouseUp:
            togglePopover(nil)
        default:
            break
        }
    }

    func applicationWillTerminate(_: Notification) {
        return
    }

    func setTitle(title: String?) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center

        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular),
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
            NSAttributedString.Key.baselineOffset: 0
        ]

        // Keep the menu bar item unshaded to match standard menu bar appearance.
        statusBarItem?.button?.layer?.backgroundColor = NSColor.clear.cgColor

        let attributedTitle = NSAttributedString(
            string: title != nil ? " \(title!)" : "",
            attributes: attributes
        )
        statusBarItem?.button?.attributedTitle = attributedTitle
    }

    func setIcon(name: NSImage.Name) {
        statusBarItem?.button?.image = NSImage(named: name)
    }

    func showPopover(_: AnyObject?) {
        if let button = statusBarItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.keyWindow?.makeFirstResponder(nil)
            NotificationCenter.default.post(name: .tbPopoverDidShow, object: nil)
        }
    }

    func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }

    func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    func checkForUpdates() {
        #if SPARKLE
        updaterController.checkForUpdates(nil)
        #else
        NSLog("ShuchuBar: Auto-update is not available in this build")
        #endif
    }
}

#if SPARKLE
class TBStatusItemUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }
}
#endif
