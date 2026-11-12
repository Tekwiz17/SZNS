<p align="center"><img src="SZNS/Assets.xcassets/AppIcon.appiconset/icon-128.png" width="96" alt="Four seasonal lights"></p>

# SZNS for macOS

Hang a strand of warm lights from the Dock, tuck icicles under the menu bar, or let petals drift across the desktop. SZNS is an independent, open-source adaptation of [Festivitas](https://festivitas.app/) by **Tekwiz17**. The implementation, interface artwork and seasonal scenes in this repository are original.

## Open in Xcode

1. Download **Code → Download ZIP** from this repository and unzip it.
2. On a Mac, open **SZNS.xcodeproj** in **Xcode 16 or newer**. The app targets macOS Sonoma 14 and newer.
3. Select the **SZNS** scheme and **My Mac**, then press **⌘R**. The project uses **Sign to Run Locally**. There are no package dependencies, signing team, certificates or provisioning profiles to configure.
4. Follow the welcome guide. Grant SZNS access in **System Settings → Privacy & Security → Accessibility** to locate the Dock. You can skip this and use menu bar lights and desktop effects immediately.

To build a copy to keep, use the command below from the unzipped folder, then quit the development copy and move **build/Build/Products/Release/SZNS.app** to Applications. Run it there before enabling **Launch at login**. If a local rebuild changes the app’s identity, macOS may ask you to grant Accessibility again.

~~~~sh
xcodebuild -project SZNS.xcodeproj -scheme SZNS -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build build
~~~~

### Opening a downloaded app

Tekwiz17 uses Apple’s free developer option. Distributed builds use a local ad-hoc signature and do not carry a Developer ID signature or Apple notarization. Building the source on your own Mac is the primary installation path.

If you trust a downloaded SZNS.app and Gatekeeper blocks it as unidentified, try opening it once in Finder. Open **System Settings → Privacy & Security**, scroll to **Security**, choose **Open Anyway** for SZNS, and confirm. This creates an exception for that copy of SZNS. Keep system-wide Gatekeeper settings enabled. [Apple’s instructions](https://support.apple.com/en-us/102445)

## Make a scene

| Settings | What you can change |
| --- | --- |
| General | Show SZNS in the Dock, menu bar, both or neither. Set launch at login, power saving and Accessibility access, or replay the guide. |
| Presets | Apply Cherry Orchard, Firefly Hour, Amber Grove or First Frost. Save, duplicate, rename, update or delete a complete scene. Create and edit named palettes or share them as JSON. |
| Menu Bar | Choose placement above apps or on the desktop. Edit bulb design, spacing, size, density, pattern, speed, variation, opacity and pointer behavior. Adjust the wire color, thickness, span and sag. |
| Dock | Independently configure the same settings for the Dock. Its strand follows the Dock’s visible bounds and orientation. |
| Desktop | Choose snowfall, autumn leaves, petals, fireflies, rain or fireworks. Adjust particle amount, size, motion, wind, opacity and colors. Falling particles can part around the pointer. Effects stay on the desktop. |

Each strand can use a color palette, a white-light temperature or a custom bulb silhouette. Choose **Import SVG** for a standalone SVG. SZNS stores a small mask with the scene so you can move the original file afterward. **Year digits** and **Year badge** use the current calendar year.

The menu bar icon provides independent switches for all three layers. Clicking the Dock icon opens Settings. If you hide both icons, launch SZNS again with Spotlight or Finder to reopen Settings. Changing a setting updates the current scene immediately. To replace a saved scene, use **Presets → … → Update from current settings**.

## Shortcuts and Siri

Run SZNS once, open **Shortcuts** on the Mac, create a shortcut, and search for **SZNS** in the action library.

- **Switch SZNS Decoration** turns a layer on, turns it off or toggles it.
- **Apply SZNS Scene** recalls a named scene, including its colors, bulbs and cable settings.
- **Set SZNS Light Pattern** sets a strand’s animation, speed and variation.
- **Adjust SZNS Light Setting** changes one setting, such as bulb size, white-light temperature or cable drop height.
- **Set SZNS Desktop Effect** selects an effect with the amount, size, speed, wind and pointer repulsion you specify.

For example, make a shortcut named **Start Firefly Hour**, add **Apply SZNS Scene**, and choose **Firefly Hour**. Then ask Siri to “Start Firefly Hour.” macOS exposes App Intents as actions for user-created shortcuts. [Apple’s App Shortcuts guide](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts)

## Build checks

The **Build SZNS** workflow builds the Release scheme on macOS, checks the local signature, app icon and App Intents metadata, and packages the app. The settings and geometry checks can also run directly on a Mac with Xcode command-line tools:

~~~~sh
swiftc SZNS/Scene.swift SZNS/DisplayGeometry.swift Tests/main.swift -o /tmp/szns-checks
/tmp/szns-checks
~~~~

For a hands-on check, move and resize the Dock, try its three orientations and auto-hide, and switch displays and Spaces. Open an app over the desktop to check both menu bar placement modes. Save a scene with a custom SVG, quit, reopen and apply it. Try a named shortcut and sleep/wake the Mac. Accessibility approval, real Dock animations and Siri voice invocation require an interactive Mac session.

Settings live in **~/Library/Application Support/SZNS/Preferences.json**. SZNS stores its scenes and imported bulb masks locally.

## License

[MIT](LICENSE).

