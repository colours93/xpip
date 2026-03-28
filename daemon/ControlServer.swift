import Foundation

class ControlServer {
    private let port: UInt16 = 51789
    private var serverSocket: Int32 = -1
    private let clientQueue = DispatchQueue(label: "com.xpip.clients", attributes: .concurrent)

    func start() {
        DispatchQueue.global(qos: .utility).async { [self] in
            serverSocket = socket(AF_INET, SOCK_STREAM, 0)
            guard serverSocket >= 0 else {
                print("Failed to create socket")
                return
            }

            var opt: Int32 = 1
            setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = port.bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")

            let bindResult = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bindResult == 0 else {
                print("Failed to bind to port \(port)")
                return
            }

            listen(serverSocket, 5)
            print("Control server listening on http://127.0.0.1:\(port)")

            while true {
                let client = accept(serverSocket, nil, nil)
                guard client >= 0 else { continue }
                clientQueue.async { [self] in
                    self.handleClient(client)
                }
            }
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { close(fd) }

        // Set 2-second read timeout
        var tv = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var buffer = [UInt8](repeating: 0, count: 8192)
        let n = read(fd, &buffer, buffer.count)
        guard n > 0 else { return }

        let request = String(bytes: buffer[..<n], encoding: .utf8) ?? ""
        let firstLine = request.components(separatedBy: "\r\n").first ?? ""

        let bodyStart = request.range(of: "\r\n\r\n")
        let body = bodyStart.map { String(request[$0.upperBound...]) } ?? ""

        let cors = "Access-Control-Allow-Origin: *\r\n"
            + "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
            + "Access-Control-Allow-Headers: Content-Type"

        if firstLine.starts(with: "OPTIONS") {
            let resp = "HTTP/1.1 204 No Content\r\n\(cors)\r\n\r\n"
            write(fd, resp, resp.utf8.count)
            return
        }

        // Serve WAD files from ~/.xpip/wads/ (e.g. GET /wads/freedoom1.wad)
        if firstLine.contains("GET /wads/") {
            let parts = firstLine.split(separator: " ")
            let pathPart = parts.count > 1 ? String(parts[1]) : ""
            if pathPart.hasPrefix("/wads/"), pathPart.count > 6 {
                let name = String(pathPart.dropFirst(6)).split(separator: "?").first.map(String.init) ?? ""
                if !name.isEmpty, name == name.filter({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }) {
                    let wadDir = NSString("~/.xpip/wads").expandingTildeInPath
                    let path = (wadDir as NSString).appendingPathComponent(name)
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: path)), !data.isEmpty {
                        let head = "HTTP/1.1 200 OK\r\n\(cors)\r\nContent-Type: application/octet-stream\r\nContent-Length: \(data.count)\r\n\r\n"
                        write(fd, head, head.utf8.count)
                        _ = data.withUnsafeBytes { write(fd, $0.baseAddress!, data.count) }
                        return
                    }
                }
            }
        }

        guard let responseBody = routeRequest(firstLine: firstLine, body: body) else {
            let resp = "HTTP/1.1 404 Not Found\r\n\(cors)\r\nContent-Length: 2\r\n\r\n{}"
            write(fd, resp, resp.utf8.count)
            return
        }

        let resp = "HTTP/1.1 200 OK\r\n"
            + "Content-Type: application/json\r\n"
            + "\(cors)\r\n"
            + "Content-Length: \(responseBody.utf8.count)\r\n\r\n"
            + responseBody
        write(fd, resp, resp.utf8.count)
    }

    private func parseSource(from firstLine: String) -> String? {
        guard let qIndex = firstLine.firstIndex(of: "?") else { return nil }
        let query = String(firstLine[firstLine.index(after: qIndex)...])
            .components(separatedBy: " ").first ?? ""
        for param in query.components(separatedBy: "&") {
            let kv = param.components(separatedBy: "=")
            if kv.count == 2 && kv[0] == "source" { return kv[1] }
        }
        return nil
    }

    private func toggleOnMain(_ name: String, source: String? = nil, paddleMode: Bool = false) {
        let sema = DispatchSemaphore(value: 0)
        DispatchQueue.main.async { daemon.toggleGame(name, source: source, paddleMode: paddleMode); sema.signal() }
        sema.wait()
    }

    private func runOnMain<T>(_ block: @escaping () -> T) -> T {
        var result: T!
        let sema = DispatchSemaphore(value: 0)
        DispatchQueue.main.async { result = block(); sema.signal() }
        sema.wait()
        return result
    }

    private func parseContentSessionName(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              !name.isEmpty else {
            return nil
        }
        return name
    }

    private func availableIWADNames() -> [String] {
        let wadDir = NSString("~/.xpip/wads").expandingTildeInPath
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: wadDir) else { return [] }
        let preferred = ["freedoom1.wad", "freedoom2.wad", "doom1.wad", "doom2.wad"]
        let lowerToOriginal = Dictionary(uniqueKeysWithValues: entries.map { ($0.lowercased(), $0) })
        return preferred.compactMap { lowerToOriginal[$0] }
    }

    private func routeRequest(firstLine: String, body: String) -> String? {
        // Audio command (from popup/menu) — must be checked before /audio
        if firstLine.contains("POST /audio-cmd") {
            let source = parseSource(from: firstLine) ?? "chrome"
            guard let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "{\"error\":\"invalid json\"}"
            }

            return runOnMain {
                if let action = json["action"] as? String, action == "switchAudio" {
                    daemon.switchAudioTo(source: source)
                } else {
                    if let vol = json["volume"] as? Double {
                        daemon.setDesiredVolume(vol, source: source)
                    }
                    if let muted = json["muted"] as? Bool {
                        daemon.setDesiredMuted(muted, source: source)
                    }
                }
                let state = daemon.audioStateForSource(source)
                let vol = state?.desiredVolume ?? state?.reportedVolume ?? 1.0
                let mut = state?.desiredMuted ?? state?.reportedMuted ?? false
                return "{\"volume\":\(vol),\"muted\":\(mut)}"
            }
        }

        // Audio report (from content script polling)
        if firstLine.contains("POST /audio") {
            let source = parseSource(from: firstLine) ?? "chrome"
            guard let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "{\"error\":\"invalid json\"}"
            }

            if json["pipEnded"] as? Bool == true {
                return runOnMain {
                    daemon.clearAudioState(source: source)
                    return "{\"cleared\":true}"
                }
            }

            let volume = json["volume"] as? Double ?? 1.0
            let muted = json["muted"] as? Bool ?? false

            return runOnMain {
                let isNew = daemon.audioStateForSource(source) == nil
                let desired = daemon.reportAudio(source: source, volume: volume, muted: muted)
                if isNew { print("Audio reporting started for \(source)") }
                return "{\"volume\":\(desired.volume),\"muted\":\(desired.muted)}"
            }
        }

        if firstLine.contains("GET /status") {
            let source = parseSource(from: firstLine)
            var result = ""
            let sema = DispatchSemaphore(value: 0)
            DispatchQueue.main.async {
                let pips = findAllPipWindows()
                var parts = [
                    "\"enabled\":\(settings.enabled)",
                    "\"cooldown\":\(settings.cooldown)",
                    "\"margin\":\(Int(settings.margin))",
                    "\"cornerSize\":\(Int(settings.cornerSize))",
                    "\"glow\":\(settings.glow)",
                    "\"glowColor\":\"\(settings.glowColor)\"",
                    "\"hotkeyCode\":\(settings.hotkeyCode)",
                    "\"hotkeyFlags\":\(settings.hotkeyFlags)",
                ]

                // Per-source or global game state
                for name in Games.gameNames {
                    if let source = source {
                        parts.append("\"\(name)\":\(daemon.isGameActiveOnSource(name, source: source))")
                    } else {
                        parts.append("\"\(name)\":\(daemon.isGameActive(name))")
                    }
                }

                if let source = source {
                    parts.append("\"doomContent\":\(daemon.isContentSessionActiveOnSource("doom", source: source))")
                } else {
                    parts.append("\"doomContent\":\(daemon.isContentSessionActive("doom"))")
                }

                if let source = source {
                    parts.append("\"bounceAuto\":\(daemon.isBounceActiveOnSource(paddleMode: false, source: source))")
                    parts.append("\"bouncePaddle\":\(daemon.isBounceActiveOnSource(paddleMode: true, source: source))")
                    let hasPip = pips.contains { $0.source == source }
                    parts.append("\"pipActive\":\(hasPip)")
                    parts.append("\"videoPipActive\":\(daemon.hasVideoPip(forSource: source))")
                    parts.append("\"documentPipActive\":\(daemon.hasDocumentPip(forSource: source))")
                    let names = daemon.activeContentSessionNames(for: source)
                    let namesJSON = "[" + names.map { "\"\($0)\"" }.joined(separator: ",") + "]"
                    parts.append("\"contentSessions\":\(namesJSON)")
                } else {
                    parts.append("\"bounceAuto\":\(daemon.isBounceActive(paddleMode: false))")
                    parts.append("\"bouncePaddle\":\(daemon.isBounceActive(paddleMode: true))")
                    parts.append("\"pipActive\":\(pips.count > 0)")
                    parts.append("\"videoPipActive\":\(daemon.hasVideoPip())")
                    parts.append("\"documentPipActive\":\(daemon.hasDocumentPip())")
                    let names = daemon.activeContentSessionNames()
                    let namesJSON = "[" + names.map { "\"\($0)\"" }.joined(separator: ",") + "]"
                    parts.append("\"contentSessions\":\(namesJSON)")
                }

                parts.append("\"pipCount\":\(pips.count)")
                let sources = Array(Set(pips.map { $0.source })).sorted()
                let sourcesJSON = "[" + sources.map { "\"\($0)\"" }.joined(separator: ",") + "]"
                parts.append("\"pipSources\":\(sourcesJSON)")
                let iwadNames = self.availableIWADNames()
                let iwadsJSON = "[" + iwadNames.map { "\"\($0)\"" }.joined(separator: ",") + "]"
                parts.append("\"iwads\":\(iwadsJSON)")

                // Audio state per source
                var audioParts: [String] = []
                for (src, state) in daemon.audioStates where state.hasReported {
                    let vol = state.desiredVolume ?? state.reportedVolume
                    let mut = state.desiredMuted ?? state.reportedMuted
                    audioParts.append("\"\(src)\":{\"volume\":\(vol),\"muted\":\(mut)}")
                }
                parts.append("\"audio\":{\(audioParts.joined(separator: ","))}")

                result = "{\(parts.joined(separator: ","))}"
                sema.signal()
            }
            sema.wait()
            return result
        }

        if firstLine.contains("GET /debug") { return debugPipDiscovery() }

        if firstLine.contains("POST /toggle") {
            settings.enabled.toggle()
            print(settings.enabled ? "Dodge enabled" : "Dodge paused")
            return "{\"enabled\":\(settings.enabled)}"
        }

        if firstLine.contains("POST /restart") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { cleanup(); exit(0) }
            return "{\"restarting\":true}"
        }

        if firstLine.contains("POST /content-session/start") {
            let source = parseSource(from: firstLine) ?? "chrome"
            guard let name = parseContentSessionName(from: body) else {
                return "{\"error\":\"missing name\"}"
            }
            return runOnMain {
                daemon.setContentSessionActive(name, source: source, active: true)
                return "{\"name\":\"\(name)\",\"active\":true}"
            }
        }

        if firstLine.contains("POST /content-session/stop") {
            let source = parseSource(from: firstLine) ?? "chrome"
            guard let name = parseContentSessionName(from: body) else {
                return "{\"error\":\"missing name\"}"
            }
            return runOnMain {
                daemon.setContentSessionActive(name, source: source, active: false)
                return "{\"name\":\"\(name)\",\"active\":false}"
            }
        }

        // Bounce has special paddle-mode handling
        if firstLine.contains("POST /bounce-paddle") {
            let source = parseSource(from: firstLine)
            toggleOnMain("bounce", source: source, paddleMode: true)
            let active: Bool
            if let source = source, source != "both" {
                active = daemon.isBounceActiveOnSource(paddleMode: true, source: source)
            } else {
                active = daemon.isBounceActive(paddleMode: true)
            }
            return "{\"bouncePaddle\":\(active)}"
        }
        if firstLine.contains("POST /bounce") {
            let source = parseSource(from: firstLine)
            toggleOnMain("bounce", source: source, paddleMode: false)
            let active: Bool
            if let source = source, source != "both" {
                active = daemon.isBounceActiveOnSource(paddleMode: false, source: source)
            } else {
                active = daemon.isBounceActive(paddleMode: false)
            }
            return "{\"bounceAuto\":\(active)}"
        }

        // Generic game toggle: match "POST /<name>" against registry
        // Check longer names first so "/pipong2" doesn't match "/pipong"
        let orderedNames = Games.gameNames.sorted { $0.count > $1.count }
        for name in orderedNames {
            if name == "bounce" { continue } // handled above
            if firstLine.contains("POST /\(name)") {
                let source = parseSource(from: firstLine)
                toggleOnMain(name, source: source)
                let active: Bool
                if let source = source, source != "both" {
                    active = daemon.isGameActiveOnSource(name, source: source)
                } else {
                    active = daemon.isGameActive(name)
                }
                return "{\"\(name)\":\(active)}"
            }
        }

        if firstLine.contains("POST /settings") {
            applySettings(from: body)
            return "{\"enabled\":\(settings.enabled),"
                + "\"cooldown\":\(settings.cooldown),"
                + "\"margin\":\(Int(settings.margin)),"
                + "\"cornerSize\":\(Int(settings.cornerSize)),"
                + "\"glow\":\(settings.glow)}"
        }

        return nil
    }

    private func applySettings(from body: String) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let c = json["cooldown"] as? Double { settings.cooldown = c }
        if let m = json["margin"] as? Double { settings.margin = CGFloat(m) }
        if let e = json["enabled"] as? Bool { settings.enabled = e }
        if let cs = json["cornerSize"] as? Double { settings.cornerSize = CGFloat(cs) }
        if let g = json["glow"] as? Bool { settings.glow = g }
        if let gc = json["glowColor"] as? String { settings.glowColor = gc }
        if let hk = json["hotkeyCode"] as? Int { settings.hotkeyCode = UInt16(hk) }
        if let hf = json["hotkeyFlags"] as? Int { settings.hotkeyFlags = UInt32(hf) }

        settings.save()
        print("Settings updated: cooldown=\(settings.cooldown)"
              + " margin=\(Int(settings.margin))"
              + " cornerSize=\(Int(settings.cornerSize))"
              + " enabled=\(settings.enabled)")
    }
}
