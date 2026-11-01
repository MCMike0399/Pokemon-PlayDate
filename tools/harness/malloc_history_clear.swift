// Root-only bounded native helper; enabled explicitly by the census owner.
import Foundation
import ApplicationServices
import CryptoKit
import Darwin
import CoreGraphics

struct Refusal: Error { let reason: String }
func require(_ ok: Bool, _ why: String) throws {
    if !ok { throw Refusal(reason: why) }
}
func digest(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
}
func record(_ url: URL) throws -> [String: Any] {
    guard let value = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    else { throw Refusal(reason: "invalid metadata") }
    return value
}
func path(_ value: String) -> URL { URL(fileURLWithPath: value).resolvingSymlinksInPath() }
func bsd(_ pid: pid_t) throws -> proc_bsdinfo {
    var info = proc_bsdinfo()
    let size = MemoryLayout<proc_bsdinfo>.size
    let count = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size))
    try require(count == size && info.pbi_uid == getuid() && info.pbi_status != 5,
                "PID is absent, zombie or owned by another user")
    return info
}
func executable(_ pid: pid_t) throws -> String {
    var bytes = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
    try require(proc_pidpath(pid, &bytes, UInt32(bytes.count)) > 0, "cannot read executable")
    return String(cString: bytes)
}
func argv(_ pid: pid_t) throws -> [String] {
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var bytes = [UInt8](repeating: 0, count: 262144)
    var size = bytes.count
    let status = sysctl(&mib, UInt32(mib.count), &bytes, &size, nil, 0)
    try require(status == 0 && size > 4, "cannot read live argv")
    let argc = bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
    try require(argc == 2, "expected exact executable and PDX argv only")
    var i = 4
    while i < size && bytes[i] != 0 { i += 1 } // kernel executable path
    while i < size && bytes[i] == 0 { i += 1 }
    var result: [String] = []
    for _ in 0..<argc {
        let start = i
        while i < size && bytes[i] != 0 { i += 1 }
        try require(i < size, "truncated argv")
        result.append(String(decoding: bytes[start..<i], as: UTF8.self))
        i += 1
    }
    return result
}
func ownedLock(_ url: URL, _ owner: pid_t) throws {
    try require((try record(url))["pid"] as? Int == Int(owner), "lock metadata owner mismatch")
    // F_GETLK only queries the kernel; this descriptor never acquires a lock.
    // Census history sessions use a POSIX lock whose owner PID Darwin exposes.
    let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW)
    try require(descriptor >= 0, "owner lock cannot be opened read-only")
    defer { close(descriptor) }
    var lock = flock(l_start: 0, l_len: 0, l_pid: 0,
                     l_type: Int16(F_WRLCK), l_whence: Int16(SEEK_SET))
    try require(fcntl(descriptor, F_GETLK, &lock) == 0 &&
                lock.l_type == Int16(F_WRLCK) && lock.l_pid == owner &&
                lock.l_start == 0 && lock.l_len == 0, "exclusive owner lock unconfirmed")
}
let sdk = path("/Users/burbujamc/Developer/PlaydateSDK")
let simulatorHash = "ebaeca5c65f3d613f06c8a3d701e90c01f292f13fc66f24a680e4357c5b447cf"
func verify(_ directory: URL, _ buildHash: String, _ runHash: String) throws -> pid_t {
    let buildURL = directory.appendingPathComponent("build.json")
    let runURL = directory.appendingPathComponent("run.json")
    try require(try digest(buildURL) == buildHash && digest(runURL) == runHash, "metadata pin mismatch")
    let build = try record(buildURL), run = try record(runURL)
    guard let id = build["build_id"] as? String, id.count == 32,
          id.allSatisfy({ $0.isHexDigit }), let pid = run["pid"] as? Int, pid > 1, pid <= Int(Int32.max),
          let files = build["pdx_files"] as? [String: String], !files.isEmpty
    else { throw Refusal(reason: "missing census identity") }
    let version = try String(contentsOf: sdk.appendingPathComponent("VERSION.txt"), encoding: .utf8)
    let ini = try String(contentsOf: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
        "Library/Preferences/com.panic.Playdate Simulator.ini"), encoding: .utf8)
    try require(version.trimmingCharacters(in: .whitespacesAndNewlines) == "3.1.2" &&
        ini.components(separatedBy: .newlines).filter { $0.hasPrefix("MallocPoolSize=") }.last == "MallocPoolSize=16645684",
        "SDK version or existing 16 MiB pool setting changed")
    let bundle = directory.appendingPathComponent("DoorCensus.pdx")
    let binary = sdk.appendingPathComponent("bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator")
    try require(build["mode"] as? String == "door-census-compile-only" &&
        build["sdk_version"] as? String == "3.1.2" && build["sdk"] as? String == sdk.path &&
        build["bundle_id"] as? String == "com.poc.pokemon.doorcensus." + id &&
        build["bundle"] as? String == bundle.path && run["build_id"] as? String == id &&
        run["simulator"] as? String == binary.path && run["simulator_sha256"] as? String == simulatorHash,
        "not the pinned SDK census build/run")
    try require(try digest(binary) == simulatorHash, "SDK executable changed")
    guard let entries = FileManager.default.enumerator(at: bundle, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey])
    else { throw Refusal(reason: "missing PDX") }
    var actual: [String: String] = [:]
    for case let entry as URL in entries {
        try require(!(try entry.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink!, "PDX link refused")
        let name = String(entry.resolvingSymlinksInPath().path.dropFirst(bundle.resolvingSymlinksInPath().path.count + 1))
        if try entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true { continue }
        if entry.lastPathComponent == ".DS_Store" || entry.lastPathComponent.hasPrefix("._") { continue }
        actual[name] = try digest(entry)
    }
    try require(actual == files, "PDX payload changed")
    let owner = getppid(), live = try bsd(pid_t(pid))
    try require(owner > 1 && live.pbi_ppid == UInt32(owner), "helper must be direct child of runtime owner")
    _ = try bsd(owner)
    try require(try executable(pid_t(pid)) == binary.path && argv(pid_t(pid)) == [binary.path, bundle.path],
                "live executable/PDX mismatch")
    try ownedLock(path("/private/tmp/pokemon-playdate-simulator-\(getuid()).lock"), owner)
    try ownedLock(path("/private/tmp/pokemon-playdate-device-\(getuid()).lock"), owner)
    try ownedLock(sdk.appendingPathComponent("Disk/Data/com.poc.pokemon.doorcensus.\(id)/owner.lock"), owner)
    let again = try bsd(pid_t(pid))
    try require(live.pbi_start_tvsec == again.pbi_start_tvsec && live.pbi_start_tvusec == again.pbi_start_tvusec,
                "PID changed during verification")
    return pid_t(pid)
}
var axReadScope = "application"
func copiedAttribute(_ name: String, _ scope: String,
                     _ copy: (inout CFTypeRef?) -> AXError) throws -> CFTypeRef? {
    for attempt in 0..<2 {
        var value: CFTypeRef?
        let error = copy(&value)
        if error == .cannotComplete && attempt == 0 {
            // Attribute copies are read-only. Never replay AX actions or clicks.
            fputs("ax_read_retry attribute=\(name), scope=\(scope)\n", stderr)
            continue
        }
        if error == .noValue || error == .attributeUnsupported { return nil }
        try require(error == .success, "AX read failed: \(error.rawValue), attribute=\(name), scope=\(scope)")
        if attempt == 1 {
            fputs("ax_read_recovered attribute=\(name), scope=\(scope)\n", stderr)
        }
        return value
    }
    throw Refusal(reason: "AX read exhausted")
}
func attribute(_ element: AXUIElement, _ name: String) throws -> CFTypeRef? {
    try copiedAttribute(name, axReadScope) { value in
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
    }
}
func label(_ element: AXUIElement, _ name: String) throws -> String {
    (try attribute(element, name)) as? String ?? ""
}
func elements(_ element: AXUIElement, _ name: String) throws -> [AXUIElement] {
    (try attribute(element, name)) as? [AXUIElement] ?? []
}
func rectangle(_ element: AXUIElement) throws -> CGRect? {
    guard let position = try attribute(element, kAXPositionAttribute),
          let size = try attribute(element, kAXSizeAttribute),
          CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
    else { return nil }
    var point = CGPoint.zero, dimensions = CGSize.zero
    guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &point),
          AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &dimensions)
    else { return nil }
    return CGRect(origin: point, size: dimensions)
}
func clearUnlabelledMallocControl(_ app: AXUIElement, _ pid: pid_t,
                                 _ reverify: () throws -> Void) throws {
    // SDK 3.1.2 exposes no AX element for its bottom-row broom. Root inspected
    // the native capture: this exact 740x480 layout puts Clear at (48,462).
    // No caller can supply coordinates, a window title or a different target.
    let logs = try elements(app, kAXWindowsAttribute).filter {
        try label($0, kAXTitleAttribute) == "Malloc Log"
    }
    try require(logs.count == 1, "one Malloc Log window required")
    guard let bounds = try rectangle(logs[0]) else {
        throw Refusal(reason: "Malloc Log bounds unavailable")
    }
    try require(bounds.width == 740 && bounds.height == 480, "unqualified Malloc Log layout")
    let allWindows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    let logWindows = allWindows.filter {
        ($0[kCGWindowOwnerPID as String] as? Int) == Int(pid) &&
        ($0[kCGWindowName as String] as? String) == "Malloc Log"
    }
    try require(logWindows.count == 1, "Malloc Log native window identity is ambiguous")
    guard let windowID = logWindows[0][kCGWindowNumber as String] as? Int else {
        throw Refusal(reason: "Malloc Log native window ID unavailable")
    }
    try require(AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue) == .success,
                "Simulator cannot become frontmost")
    try require(AXUIElementPerformAction(logs[0], kAXRaiseAction as CFString) == .success,
                "Malloc Log cannot be raised")
    let point = CGPoint(x: bounds.minX + 48, y: bounds.minY + 462)
    try reverify()
    try require(try rectangle(logs[0]) == bounds, "Malloc Log moved or resized during verification")
    var hit: AXUIElement?
    try require(AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(),
                Float(point.x), Float(point.y), &hit) == .success, "Clear hit-test unavailable")
    guard let element = hit else { throw Refusal(reason: "Clear hit-test has no element") }
    var hitPID: pid_t = 0
    try require(AXUIElementGetPid(element, &hitPID) == .success && hitPID == pid,
                "Clear point belongs to another application")
    let hitWindow = try attribute(element, kAXWindowAttribute)
    let window = hitWindow.map { unsafeBitCast($0, to: AXUIElement.self) } ?? element
    try require(try label(window, kAXTitleAttribute) == "Malloc Log",
                "Clear point belongs to another Simulator window")
    guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                             mouseCursorPosition: point, mouseButton: .left),
          let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                           mouseCursorPosition: point, mouseButton: .left)
    else { throw Refusal(reason: "targeted Clear events unavailable") }
    let previousCursor = CGEvent(source: nil)?.location
    try require(try rectangle(logs[0]) == bounds, "Malloc Log moved or resized before Clear")
    try require(CGWarpMouseCursorPosition(point) == .success, "Clear cursor position unavailable")
    defer {
        if let previous = previousCursor, let current = CGEvent(source: nil)?.location,
           abs(current.x - point.x) < 2 && abs(current.y - point.y) < 2 {
            CGWarpMouseCursorPosition(previous)
        }
    }
    if let moved = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                           mouseCursorPosition: point, mouseButton: .left) {
        moved.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(windowID))
        moved.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(windowID))
        moved.post(tap: .cghidEventTap)
    }
    for event in [down, up] {
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(windowID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(windowID))
    }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
    usleep(200_000)
    print("{\"clear_requested\":true,\"mechanism\":\"verified-window-broom\",\"pid\":\(pid)}")
}
func operate(_ pid: pid_t, _ operation: String, _ directory: URL, _ reverify: () throws -> Void) throws {
    try require(AXIsProcessTrusted(), "Accessibility unavailable; no prompt requested")
    let app = AXUIElementCreateApplication(pid)
    try require(AXUIElementSetMessagingTimeout(app, 0.2) == .success, "AX timeout unavailable")
    var candidates: [AXUIElement] = [], logControls: [AXUIElement] = []
    var seen: [AXUIElement] = [], listing: [[String: String]] = []
    func walk(_ element: AXUIElement, _ scope: String, _ depth: Int) throws {
        let previousScope = axReadScope
        axReadScope = "\(scope), depth=\(depth)"
        defer { axReadScope = previousScope }
        if seen.contains(where: { CFEqual($0, element) }) { return }
        try require(seen.count < 400 && depth < 16, "AX tree exceeds bounded inspection")
        seen.append(element)
        var elementPID: pid_t = 0
        try require(AXUIElementGetPid(element, &elementPID) == .success && elementPID == pid, "foreign AX element")
        let role = try label(element, kAXRoleAttribute), title = try label(element, kAXTitleAttribute)
        var entry = ["scope": scope, "role": role, "title": title,
                     "description": try label(element, kAXDescriptionAttribute)]
        if scope == "Malloc Log" && role == kAXButtonRole {
            entry["help"] = try label(element, kAXHelpAttribute)
            entry["identifier"] = try label(element, kAXIdentifierAttribute)
            entry["value"] = try label(element, kAXValueAttribute)
            if let bounds = try rectangle(element) {
                entry["frame"] = NSStringFromRect(bounds)
            }
        }
        if scope == "Malloc Log" && role == kAXStaticTextRole {
            entry["value"] = try label(element, kAXValueAttribute)
        }
        listing.append(entry)
        if title == "Clear Malloc History" && (role == kAXMenuItemRole || (scope == "Malloc Log" && role == kAXButtonRole)) {
            candidates.append(element)
        }
        if scope == "Simulator menu" && title == "Show Malloc Log" && role == kAXMenuItemRole {
            logControls.append(element)
        }
        // Allocation rows are data, never controls. Do not enumerate thousands
        // of rows just to locate the log window's fixed buttons.
        if scope == "Malloc Log" && [kAXTableRole, kAXOutlineRole, kAXRowRole, kAXCellRole].contains(role) {
            return
        }
        for child in try elements(element, kAXChildrenAttribute) { try walk(child, scope, depth + 1) }
    }
    if let menu = try attribute(app, kAXMenuBarAttribute) {
        try require(CFGetTypeID(menu) == AXUIElementGetTypeID(), "invalid menu bar")
        try walk(unsafeBitCast(menu, to: AXUIElement.self), "Simulator menu", 0)
    }
    for window in try elements(app, kAXWindowsAttribute) {
        let title = try label(window, kAXTitleAttribute)
        var entry = ["scope": "Simulator window", "title": title]
        if let bounds = try rectangle(window) { entry["frame"] = NSStringFromRect(bounds) }
        listing.append(entry)
        if title == "Malloc Log" { try walk(window, "Malloc Log", 0) }
    }
    if operation == "inspect" {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let logs = windows.filter {
            ($0[kCGWindowOwnerPID as String] as? Int) == Int(pid) &&
            ($0[kCGWindowName as String] as? String) == "Malloc Log"
        }
        if logs.count == 1, let identifier = logs[0][kCGWindowNumber as String] as? Int {
            try reverify()
            let capture = Process()
            let target = directory.appendingPathComponent("malloc-log-inspection-\(UUID().uuidString).png")
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-l", String(identifier), target.path]
            capture.standardOutput = FileHandle.nullDevice
            capture.standardError = FileHandle.nullDevice
            try capture.run()
            capture.waitUntilExit()
            try require(capture.terminationStatus == 0 &&
                        FileManager.default.fileExists(atPath: target.path), "Malloc Log capture failed")
            listing.append(["scope": "inspection capture", "path": target.path,
                            "returncode": String(capture.terminationStatus)])
        }
        let data = try JSONSerialization.data(withJSONObject: listing, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        return
    }
    if operation == "show-log" {
        try require(logControls.count == 1, "expected one verified Show Malloc Log menu item")
        try require((try attribute(logControls[0], kAXEnabledAttribute)) as? Bool == true, "Malloc Log is not enabled")
        try reverify()
        try require(AXUIElementPerformAction(logControls[0], kAXPressAction as CFString) == .success, "Show Malloc Log AXPress failed")
        print("{\"malloc_log_open_requested\":true,\"pid\":\(pid)}")
        return
    }
    if candidates.isEmpty {
        try clearUnlabelledMallocControl(app, pid, reverify)
        return
    }
    try require(candidates.count == 1, "expected exactly one Clear Malloc History control; inspect first")
    try require((try attribute(candidates[0], kAXEnabledAttribute)) as? Bool == true, "Clear is not enabled")
    try reverify()
    try require(AXUIElementPerformAction(candidates[0], kAXPressAction as CFString) == .success, "Clear AXPress failed")
    print("{\"ax_press_accepted\":true,\"pid\":\(pid)}")
}
let started = DispatchTime.now().uptimeNanoseconds
alarm(8) // Bounds native inspection/capture; never signals the Simulator.
do {
    let args = CommandLine.arguments
    try require(args.count == 5 && ["inspect", "show-log", "clear"].contains(args[1]),
                "usage: helper inspect|show-log|clear RUN_DIRECTORY BUILD_JSON_SHA256 RUN_JSON_SHA256")
    try require(args[3].count == 64 && args[4].count == 64 && (args[3] + args[4]).allSatisfy({ $0.isHexDigit }),
                "expected SHA256 pins")
    let directory = path(args[2])
    let pid = try verify(directory, args[3], args[4])
    try operate(pid, args[1], directory) {
        try require(try verify(directory, args[3], args[4]) == pid, "runtime identity changed")
    }
    fputs("helper_elapsed_ms=\(Double(DispatchTime.now().uptimeNanoseconds - started) / 1e6)\n", stderr)
} catch {
    fputs("refused: \(error)\n", stderr)
    exit(1)
}
