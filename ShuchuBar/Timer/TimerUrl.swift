import Foundation
import Carbon

extension TBTimer {
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor,
                              withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.forKeyword(AEKeyword(keyDirectObject))?.stringValue else {
            print("url handling error: cannot get url")
            return
        }
        let url = URL(string: urlString)
        guard url != nil,
              let scheme = url!.scheme,
              let host = url!.host else {
            print("url handling error: cannot parse url")
            return
        }
        guard scheme.caseInsensitiveCompare("shuchubar") == .orderedSame else {
            print("url handling error: unknown scheme \(scheme)")
            return
        }
        handleURLCommand(host)
    }

    private func handleURLCommand(_ host: String) {
        switch host.lowercased() {
        case "startstop":
            startStop()
        case "end":
            endSession()
        default:
            print("url handling error: unknown command \(host)")
        }
    }
}
