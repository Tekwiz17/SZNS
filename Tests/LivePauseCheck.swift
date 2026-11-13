import AppKit

let pid = Int(CommandLine.arguments[1])!
let level = Int(CGWindowLevelForKey(.statusWindow)) + 1
func hasMenuStrand() -> Bool {
    let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
    return windows.contains { $0[kCGWindowOwnerPID as String] as? Int == pid && $0[kCGWindowLayer as String] as? Int == level }
}
Thread.sleep(forTimeInterval: 1)
precondition(kill(Int32(pid), 0) == 0 && !hasMenuStrand(), "Timed pause did not suppress the running app’s menu strand")
let timeout = Date().addingTimeInterval(25)
while !hasMenuStrand() && Date() < timeout { Thread.sleep(forTimeInterval: 0.25) }
precondition(hasMenuStrand(), "Menu strand did not resume automatically")
print("PASS relaunch honors timed pause and restores the menu strand at expiry")
