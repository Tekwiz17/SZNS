import SwiftUI
import AppKit

struct WelcomeView: View {
    @ObservedObject var studio: Studio
    @ObservedObject var nav: Navigation
    @State private var step = 0
    @State private var season: Season?
    @State private var prompted = false
    private let titles = ["Welcome to SZNS", "Lights that follow your Dock", "Choose your first scene", "Make yourself at home"]
    private let details = [
        "Hang a string of lights beneath the menu bar, trim the Dock, and give your desktop a season of its own.",
        "Allow Accessibility so SZNS can find the Dock as you move it, resize it, or switch displays. You can continue and grant access later.",
        "Try a season below. Each scene combines two strings of lights with a desktop effect. You can change any detail afterward.",
        "Click the SZNS icon in the Dock or choose Settings from its menu bar icon. If you hide both icons, open SZNS from Finder or Spotlight."
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScenePreview(scene: season?.scene ?? studio.prefs.scene, focus: step == 1 ? .dock : nil)
                .frame(height: 145)
            HStack(spacing: 9) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 34, height: 34)
                Text(titles[step]).font(.title2.weight(.semibold))
            }
            Text(details[step]).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if step == 1 {
                if nav.trusted { Label("Accessibility is enabled", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                else { Button("Open Accessibility Settings…") { Accessibility.request(); Accessibility.openSettings() } }
            }
            if step == 2 {
                Picker("Season", selection: $season) {
                    Text("Current").tag(nil as Season?)
                    ForEach(Season.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }.labelsHidden()
            }
            Spacer(minLength: 4)
            Divider()
            HStack {
                if step > 0 { Button("Back") { step -= 1 } }
                Spacer()
                Text("\(step + 1) of \(titles.count)").font(.caption).foregroundStyle(.secondary)
                Button(step == 3 ? "Start SZNS" : "Continue") {
                    if step == 3 {
                        if let season { studio.prefs.scene = season.scene }
                        studio.prefs.welcomed = true; nav.showingGuide = false
                    } else {
                        step += 1
                        if step == 1 && !nav.trusted && !prompted { prompted = true; Accessibility.request() }
                    }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(22).frame(width: 490, height: 410)
    }
}
