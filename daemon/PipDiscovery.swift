import Cocoa
import ApplicationServices

// MARK: - Shared Types

extension CGRect {
    /// Inset a rect by NSEdgeInsets (shrinks the rect by the given amounts).
    func insetBy(_ insets: NSEdgeInsets) -> CGRect {
        CGRect(x: origin.x + insets.left,
               y: origin.y + insets.top,
               width: width - insets.left - insets.right,
               height: height - insets.top - insets.bottom)
    }
}

struct PipID: Hashable {
    let element: AXUIElement
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
    static func == (lhs: PipID, rhs: PipID) -> Bool { CFEqual(lhs.element, rhs.element) }
}

enum PipWindowKind: String {
    case video
    case document
}

struct PipWindowInfo {
    let bounds: CGRect
    let axWindow: AXUIElement
    let source: String   // "chrome" or "safari"
    let kind: PipWindowKind
    /// Insets from window bounds to actual video content (non-zero for Safari PIPAgent).
    var contentInsets: NSEdgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    var id: PipID { PipID(element: axWindow) }

    /// Bounds of the visible video content (window bounds minus chrome insets).
    var contentBounds: CGRect {
        CGRect(x: bounds.origin.x + contentInsets.left,
               y: bounds.origin.y + contentInsets.top,
               width: bounds.width - contentInsets.left - contentInsets.right,
               height: bounds.height - contentInsets.top - contentInsets.bottom)
    }
}

// MARK: - Discovery

/// Returns rects of all windows above normal level (floating/PiP).
func floatingWindowRects() -> [CGRect] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
        return []
    }
    var rects: [CGRect] = []
    for info in list {
        guard let layer = info[kCGWindowLayer as String] as? Int, layer > 0,
              let bd = info[kCGWindowBounds as String] as? [String: Any] else { continue }
        let x = (bd["X"] as? NSNumber)?.doubleValue ?? 0
        let y = (bd["Y"] as? NSNumber)?.doubleValue ?? 0
        let w = (bd["Width"] as? NSNumber)?.doubleValue ?? 0
        let h = (bd["Height"] as? NSNumber)?.doubleValue ?? 0
        rects.append(CGRect(x: x, y: y, width: w, height: h))
    }
    return rects
}

func findAllPipWindows() -> [PipWindowInfo] {
    let floating = floatingWindowRects()
    var results: [PipWindowInfo] = []
    results.append(contentsOf: findChromePipWindows(floating: floating))
    results.append(contentsOf: findSafariPipWindows())
    return results
}

func findPipWindow() -> PipWindowInfo? {
    findAllPipWindows().first { $0.kind == .video }
}

func findPipWindow(source: String) -> PipWindowInfo? {
    findAllPipWindows().first { $0.source == source && $0.kind == .video }
}

// MARK: - Debug

func debugPipDiscovery() -> String {
    var out = ""
    let chromeApps = NSWorkspace.shared.runningApplications.filter {
        ($0.localizedName ?? "").contains("Chrome")
            || ($0.bundleIdentifier ?? "").contains("chrome")
    }
    let pipAgentApps = NSWorkspace.shared.runningApplications.filter {
        ($0.bundleIdentifier ?? "") == "com.apple.PIPAgent"
    }
    out += "AXTrusted: \(AXIsProcessTrusted())\n"
    out += "chromeApps: \(chromeApps.map { "\($0.localizedName ?? "?") pid=\($0.processIdentifier)" })\n"
    out += "pipAgentApps: \(pipAgentApps.map { "\($0.localizedName ?? "?") pid=\($0.processIdentifier)" })\n"
    let floating = floatingWindowRects()
    out += "floatingRects: \(floating.count)\n"
    for (i, r) in floating.enumerated() { out += "  float[\(i)] \(r)\n" }
    for app in chromeApps + pipAgentApps {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
        guard let windows = windowsRef as? [AXUIElement] else {
            out += "  \(app.localizedName ?? "?"): AX error \(err.rawValue)\n"
            continue
        }
        out += "\(app.localizedName ?? "?"): \(windows.count) windows\n"
        for (i, w) in windows.enumerated() {
            var tRef: CFTypeRef?; _ = AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &tRef)
            var pRef: CFTypeRef?; _ = AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &pRef)
            var sRef: CFTypeRef?; _ = AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &sRef)
            var rRef: CFTypeRef?; _ = AXUIElementCopyAttributeValue(w, kAXRoleAttribute as CFString, &rRef)
            var srRef: CFTypeRef?; _ = AXUIElementCopyAttributeValue(w, kAXSubroleAttribute as CFString, &srRef)
            var minRef: CFTypeRef?
            let hasMin = AXUIElementCopyAttributeValue(w, kAXMinimizeButtonAttribute as CFString, &minRef) == .success && minRef != nil
            var clRef: CFTypeRef?
            let hasCl = AXUIElementCopyAttributeValue(w, kAXCloseButtonAttribute as CFString, &clRef) == .success && clRef != nil
            var pos = CGPoint.zero; var size = CGSize.zero
            if let pv = pRef { AXValueGetValue(pv as! AXValue, .cgPoint, &pos) }
            if let sv = sRef { AXValueGetValue(sv as! AXValue, .cgSize, &size) }
            let ratio = size.height > 0 ? size.width / size.height : 0
            let title = (tRef as? String) ?? ""
            let matchFloat = floating.contains { r in
                abs(r.origin.x - pos.x) < 3 && abs(r.origin.y - pos.y) < 3
                    && abs(r.width - size.width) < 3 && abs(r.height - size.height) < 3
            }
            out += "  [\(i)] \"\(title.prefix(40))\" \(Int(size.width))x\(Int(size.height)) ratio=\(String(format:"%.2f", ratio)) role=\(rRef as? String ?? "-") sub=\(srRef as? String ?? "-") min=\(hasMin) close=\(hasCl) float=\(matchFloat)\n"

            // Dump AX children for PIPAgent windows
            if (app.bundleIdentifier ?? "") == "com.apple.PIPAgent" {
                debugPipAgentChildren(window: w, out: &out)
            }
        }
    }
    let pips = findAllPipWindows()
    out += "findAllPipWindows: \(pips.count)\n"
    for (i, p) in pips.enumerated() { out += "  pip[\(i)] \(p.source) bounds: \(p.bounds)\n" }
    return out
}

private func debugPipAgentChildren(window: AXUIElement, out: inout String) {
    var childrenRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenRef) == .success,
          let children = childrenRef as? [AXUIElement] else {
        out += "    children: none\n"
        return
    }
    out += "    children: \(children.count)\n"
    for (ci, child) in children.enumerated() {
        var cRole: CFTypeRef?; _ = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &cRole)
        var cSub: CFTypeRef?; _ = AXUIElementCopyAttributeValue(child, kAXSubroleAttribute as CFString, &cSub)
        var cPos: CFTypeRef?; _ = AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &cPos)
        var cSize: CFTypeRef?; _ = AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &cSize)
        var cDesc: CFTypeRef?; _ = AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &cDesc)
        var cp = CGPoint.zero; var cs = CGSize.zero
        if let v = cPos { AXValueGetValue(v as! AXValue, .cgPoint, &cp) }
        if let v = cSize { AXValueGetValue(v as! AXValue, .cgSize, &cs) }
        out += "    child[\(ci)] role=\(cRole as? String ?? "-") sub=\(cSub as? String ?? "-") \(Int(cs.width))x\(Int(cs.height)) at (\(Int(cp.x)),\(Int(cp.y))) desc=\(cDesc as? String ?? "-")\n"
    }
}
