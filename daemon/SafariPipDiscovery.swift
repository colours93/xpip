import Cocoa
import ApplicationServices

// MARK: - Safari PiP Discovery (PIPAgent)
//
// Safari PiP runs via macOS PIPAgent (com.apple.PIPAgent).
// All PIPAgent windows are PiP by definition — no heuristic filtering needed.
// Glow border uses raw window bounds (same approach as Chrome PiP).

func findSafariPipWindows() -> [PipWindowInfo] {
    let pipAgentApps = NSWorkspace.shared.runningApplications.filter {
        ($0.bundleIdentifier ?? "") == "com.apple.PIPAgent"
    }

    var results: [PipWindowInfo] = []
    for app in pipAgentApps {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            continue
        }
        for window in windows {
            if let info = extractSafariPipWindow(from: window) {
                results.append(info)
            }
        }
    }
    return results
}

// MARK: - Window Extraction

/// Extract PiP info from a PIPAgent window. Computes content insets from child elements.
private func extractSafariPipWindow(from window: AXUIElement) -> PipWindowInfo? {
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

    guard size.width >= 100 && size.height >= 50 else { return nil }

    let bounds = CGRect(origin: pos, size: size)
    let insets = computePipAgentContentInsets(window: window, windowBounds: bounds)
    return PipWindowInfo(bounds: bounds, axWindow: window, source: "safari", kind: .video, contentInsets: insets)
}

/// Derive content insets from PIPAgent child element positions (controls sit at video edges).
private func computePipAgentContentInsets(window: AXUIElement, windowBounds: CGRect) -> NSEdgeInsets {
    var childrenRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenRef) == .success,
          let children = childrenRef as? [AXUIElement], !children.isEmpty else {
        return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    var minX = CGFloat.infinity, minY = CGFloat.infinity
    var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity

    for child in children {
        var cPos: CFTypeRef?
        var cSize: CFTypeRef?
        guard AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &cPos) == .success,
              AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &cSize) == .success else {
            continue
        }
        var cp = CGPoint.zero
        var cs = CGSize.zero
        AXValueGetValue(cPos as! AXValue, .cgPoint, &cp)
        AXValueGetValue(cSize as! AXValue, .cgSize, &cs)
        guard cs.width > 0 && cs.height > 0 else { continue }
        minX = min(minX, cp.x)
        minY = min(minY, cp.y)
        maxX = max(maxX, cp.x + cs.width)
        maxY = max(maxY, cp.y + cs.height)
    }

    guard minX < maxX && minY < maxY else {
        return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    let left = max(0, minX - windowBounds.origin.x)
    let top = max(0, minY - windowBounds.origin.y)
    let right = max(0, (windowBounds.origin.x + windowBounds.width) - maxX)
    let bottom = max(0, (windowBounds.origin.y + windowBounds.height) - maxY)
    return NSEdgeInsets(top: top, left: left, bottom: bottom, right: right)
}
