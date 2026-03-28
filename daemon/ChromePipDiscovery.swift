import Cocoa
import ApplicationServices

// MARK: - Chrome PiP Discovery
//
// Chrome creates its own PiP windows as regular AXWindow elements.
// Detection uses heuristics: title matching ("Picture in Picture"),
// floating layer check, AX role/subrole filtering, and size constraints.
// Chrome PiP windows have no minimize/close buttons and sit above normal level.

func findChromePipWindows(floating: [CGRect]) -> [PipWindowInfo] {
    let chromeApps = NSWorkspace.shared.runningApplications.filter {
        ($0.localizedName ?? "").contains("Chrome")
            || ($0.bundleIdentifier ?? "").contains("chrome")
    }

    var results: [PipWindowInfo] = []
    for app in chromeApps {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            continue
        }
        for window in windows {
            if let info = extractChromePipInfo(from: window, floating: floating) {
                results.append(info)
            }
        }
    }
    return results
}

private func extractChromePipInfo(from window: AXUIElement, floating: [CGRect]) -> PipWindowInfo? {
    var titleRef: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
    let title = (titleRef as? String) ?? ""

    var posRef: CFTypeRef?
    var sizeRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
          AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else {
        return nil
    }

    var pos = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
    AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

    let isPip = title.localizedCaseInsensitiveContains("picture in picture")
        || title.localizedCaseInsensitiveContains("picture-in-picture")

    // Confirm the window is in the floating layer (above normal window level).
    let matchesFloat = floating.contains { r in
        abs(r.origin.x - pos.x) < 3 && abs(r.origin.y - pos.y) < 3
            && abs(r.width - size.width) < 3 && abs(r.height - size.height) < 3
    }

    // AX role/subrole filtering to reject popups, autofill dropdowns, dialogs.
    var roleRef: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
    let role = (roleRef as? String) ?? ""

    var subroleRef: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef)
    let subrole = (subroleRef as? String) ?? ""

    let popupSubroles: Set<String> = ["AXDialog", "AXSystemDialog", "AXFloatingWindow"]
    let invalidRoles: Set<String> = ["AXPopover", "AXSheet"]

    let hasValidAXAttributes = (role == "" || role == "AXWindow")
        && !popupSubroles.contains(subrole)
        && !invalidRoles.contains(role)

    // Reject windows with minimize/close buttons — real Chrome PiP has neither.
    var minimizeRef: CFTypeRef?
    let hasMinimize = AXUIElementCopyAttributeValue(window, kAXMinimizeButtonAttribute as CFString, &minimizeRef) == .success
        && minimizeRef != nil

    var closeRef: CFTypeRef?
    let hasClose = AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeRef) == .success
        && closeRef != nil

    // Document PiP: untitled, landscape, floating, no buttons, size-constrained.
    let isDocPip = (title == "" || title == "about:blank")
        && matchesFloat
        && hasValidAXAttributes
        && !hasMinimize
        && !hasClose
        && size.width >= 200 && size.width <= 800
        && size.height >= 100 && size.height <= 600
        && (size.width / size.height) > 1.4

    // Title-matched PiP: title contains "Picture in Picture", confirmed floating.
    let isTitledPip = isPip && matchesFloat

    guard isTitledPip || isDocPip else { return nil }

    let bounds = CGRect(origin: pos, size: size)
    let kind: PipWindowKind = isDocPip ? .document : .video
    return PipWindowInfo(bounds: bounds, axWindow: window, source: "chrome", kind: kind)
}
