// Host-only, deliberately not wired into any runner. See malloc_history_clear.md.
import Foundation
import ApplicationServices
import CryptoKit
import Darwin

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
    // Read kernel lock reporting; never open for write, acquire or release a lock.
    let task = Process(), pipe = Pipe()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    task.arguments = ["-nP", "-b", "-S2", "-a", "-p", String(owner), "-Fpln", "--", url.path]
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    try task.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
    try require(task.terminationStatus == 0 && lines.contains("p\(owner)") &&
                lines.contains("lW") && lines.contains("n" + url.path), "exclusive owner lock unconfirmed")
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
func attribute(_ element: AXUIElement, _ name: String) throws -> CFTypeRef? {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    if error == .noValue || error == .attributeUnsupported { return nil }
    try require(error == .success, "AX read failed: \(error.rawValue)")
    return value
}
func label(_ element: AXUIElement, _ name: String) throws -> String {
    (try attribute(element, name)) as? String ?? ""
}
func elements(_ element: AXUIElement, _ name: String) throws -> [AXUIElement] {
    (try attribute(element, name)) as? [AXUIElement] ?? []
}
func operate(_ pid: pid_t, _ clear: Bool, _ reverify: () throws -> Void) throws {
    try require(AXIsProcessTrusted(), "Accessibility unavailable; no prompt requested")
    let app = AXUIElementCreateApplication(pid)
    try require(AXUIElementSetMessagingTimeout(app, 0.2) == .success, "AX timeout unavailable")
    var candidates: [AXUIElement] = [], seen: [AXUIElement] = [], listing: [[String: String]] = []
    func walk(_ element: AXUIElement, _ scope: String, _ depth: Int) throws {
        if seen.contains(where: { CFEqual($0, element) }) { return }
        try require(seen.count < 400 && depth < 16, "AX tree exceeds bounded inspection")
        seen.append(element)
        var elementPID: pid_t = 0
        try require(AXUIElementGetPid(element, &elementPID) == .success && elementPID == pid, "foreign AX element")
        let role = try label(element, kAXRoleAttribute), title = try label(element, kAXTitleAttribute)
        listing.append(["scope": scope, "role": role, "title": title,
                        "description": try label(element, kAXDescriptionAttribute)])
        if title == "Clear Malloc History" && (role == kAXMenuItemRole || (scope == "Malloc Log" && role == kAXButtonRole)) {
            candidates.append(element)
        }
        for child in try elements(element, kAXChildrenAttribute) { try walk(child, scope, depth + 1) }
    }
    if let menu = try attribute(app, kAXMenuBarAttribute) {
        try require(CFGetTypeID(menu) == AXUIElementGetTypeID(), "invalid menu bar")
        try walk(unsafeBitCast(menu, to: AXUIElement.self), "Simulator menu", 0)
    }
    for window in try elements(app, kAXWindowsAttribute) {
        let title = try label(window, kAXTitleAttribute)
        listing.append(["scope": "Simulator window", "title": title])
        if title == "Malloc Log" { try walk(window, "Malloc Log", 0) }
    }
    if !clear {
        let data = try JSONSerialization.data(withJSONObject: listing, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        return
    }
    try require(candidates.count == 1, "expected exactly one Clear Malloc History control; inspect first")
    try require((try attribute(candidates[0], kAXEnabledAttribute)) as? Bool == true, "Clear is not enabled")
    try reverify()
    try require(AXUIElementPerformAction(candidates[0], kAXPressAction as CFString) == .success, "Clear AXPress failed")
    print("{\"ax_press_accepted\":true,\"pid\":\(pid)}")
}
let started = DispatchTime.now().uptimeNanoseconds
alarm(8) // Bounds this helper, including lsof and unresponsive AX. Never signals the Simulator.
do {
    let args = CommandLine.arguments
    try require(args.count == 5 && ["inspect", "clear"].contains(args[1]),
                "usage: helper inspect|clear RUN_DIRECTORY BUILD_JSON_SHA256 RUN_JSON_SHA256")
    try require(args[3].count == 64 && args[4].count == 64 && (args[3] + args[4]).allSatisfy({ $0.isHexDigit }),
                "expected SHA256 pins")
    let directory = path(args[2])
    let pid = try verify(directory, args[3], args[4])
    try operate(pid, args[1] == "clear") {
        try require(try verify(directory, args[3], args[4]) == pid, "runtime identity changed")
    }
    fputs("helper_elapsed_ms=\(Double(DispatchTime.now().uptimeNanoseconds - started) / 1e6)\n", stderr)
} catch {
    fputs("refused: \(error)\n", stderr)
    exit(1)
}
