<p align="center"><img src="SZNS/Assets.xcassets/AppIcon.appiconset/icon-128.png" width="96" alt="SZNS four-petal glass icon"></p>

# SZNS for macOS

Hang a strand of warm lights from the Dock, tuck icicles under the menu bar, or let petals drift across the desktop. SZNS is an independent, open-source adaptation of [Festivitas](https://festivitas.app/) by **Tekwiz17**. The implementation, interface artwork and seasonal scenes in this repository are original.

## Install the app

[Download SZNS for macOS](https://github.com/Tekwiz17/SZNS/releases/latest/download/SZNS-macOS.zip), unzip it, then move **SZNS.app** to Applications. The release ZIP includes both Intel and Apple silicon. See **Opening a downloaded app** below for Gatekeeper instructions.

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
| General | Show SZNS in the Dock, menu bar, both or neither. Set launch at login, power saving, wallpaper previews and Accessibility access. Check for new releases or replay the guide. |
| Presets | Apply one of 22 ready-made scenes or use any of their palettes on a single layer. Save, duplicate, rename, update or delete a complete scene. Create and edit named palettes or share them as JSON. |
| Menu Bar | Choose placement above apps or on the desktop. Edit bulb design, spacing, size, density, pattern, speed, variation, opacity and pointer behavior. Adjust the wire color, thickness, span and sag. |
| Dock | Independently configure the same settings for the Dock. Its strand follows the Dock’s visible bounds and orientation. |
| Desktop | Choose snow, leaves, petals, fireflies, rain, fireworks, bats, ghosts, confetti, a repeating midnight ball drop, aurora curtains, a meteor shower, drifting jellyfish, swimming koi, rising lanterns or tide pool bubbles. Adjust particle amount, size, motion, wind, opacity and colors. Falling particles can part around the pointer. Effects stay on the desktop. |

### Take a break

Open **Settings → General → Quiet Hours** to set a daily start and end in local time. An overnight window such as 10 PM to 7 AM works across midnight. Equal start and end times leave the schedule inactive. **Pause Decorations** in the menu bar, or **Pause for…** in General, gives you a 15-, 30-, or 60-minute break. You can end the timed pause early. Quiet Hours still applies during its scheduled window. You can edit or preview scenes while the desktop is paused.

### Find your next scene

Open **Settings → Presets** and search by name, bulb or desktop effect. For example, type **jellyfish** to find Moonlit Reef. Click the eye beside a scene to preview it. Select the layers you want to borrow. For example, keep your Dock and menu bar lights and bring in just the bubbles from **Sea Glass**. The preview shows the mix before you apply it. Use **Save current scene** to keep your combination. Star a scene to pin it to the top of the menu bar’s **Apply Scene** menu. Favorites persist after quitting.

### Celebrations

Every scene below also ships as a named color palette.

| Scene | Menu bar and Dock bulbs | Desktop |
| --- | --- | --- |
| Sea Glass | Tumbled glass on both strands | Translucent rising bubbles |
| Lantern Festival | Paper sky lanterns and lantern bulbs | Rising lanterns with warm centers |
| Koi Pond | Koi and blossoms | Swimming koi with trailing ripples |
| Northern Lights | Crystal prisms and icicles | Slow curtains of mint, blue and violet light |
| Perseid Night | Ringed planets and stars | A star field with passing meteors |
| Moonlit Reef | Jellyfish and seashells | Translucent jellyfish float upward |
| Candy Cane | Striped canes and peppermint diodes | Soft snow |
| Christmas Bulbs | Classic multicolor bulbs on both strands | Warm-white snow |
| Christmas Red & Green | Pine trees and classic bulbs | Snow |
| 4th of July | Red, white and blue stars and globes | Fireworks |
| Fall Leaves | Maple leaves and pumpkins | Drifting leaves |
| Easter Pastel | Painted eggs and blossoms | Pastel petals |
| Halloween Black & Orange | Pumpkins and bats | Flying bats |
| Halloween Witch | Green and purple moons and ghosts | Floating ghosts |
| Midnight Countdown | Stars and year digits | A mirror ball drops and releases sparks |
| Tassel Toss | Graduation caps and stars | Tumbling confetti |
| Love Letters | Hearts and blossoms | Rose petals |
| Summer Solstice | Suns and shells | Fireflies |

Cherry Orchard, Firefly Hour, Amber Grove and First Frost round out the collection. On upgrade, SZNS adds the new scenes and palettes once and preserves your current scene and saved presets.

Each strand can use a color palette, a white-light temperature or a custom bulb silhouette. Choose **Import SVG** for a standalone SVG. SZNS stores a small mask with the scene so you can move the original file afterward. **Year digits** and **Year badge** use the current calendar year.

Bulb size runs from 3 to 64 points. The starter scenes use 18–20 pt bulbs on the Dock and 22–24 pt bulbs at the menu bar. SZNS fits the strand inside the visible Dock when a small Dock leaves less room. Increase the system Dock size to give larger bulbs more space.

In **Settings → Dock**, **Dock tracking** shows the edge and display SZNS found. If tracking asks for Accessibility, enable SZNS in System Settings and reveal the Dock. Choose **Whenever the Dock is visible** for normal use, or **While using Finder** to show the lights only while Finder is active.

The menu bar icon provides independent switches for all three layers and an **Apply Scene** submenu. Clicking the Dock icon opens Settings. If you hide both icons, launch SZNS again with Spotlight or Finder to reopen Settings. Changing a setting updates the current scene immediately. To replace a saved scene, use **Presets → … → Update from current settings**.

## Shortcuts and Siri

Run SZNS once, open **Shortcuts** on the Mac, create a shortcut, and search for **SZNS** in the action library.

- **Switch SZNS Decoration** turns a layer on, turns it off or toggles it.
- **Apply SZNS Scene** recalls a named scene, including its colors, bulbs and cable settings.
- **Set SZNS Light Pattern** sets a strand’s animation, speed and variation.
- **Style SZNS Light String** sets a bulb design, placement, color palette or cable color.
- **Adjust SZNS Light Setting** changes one setting, such as bulb size, white-light temperature or cable drop height.
- **Set SZNS Desktop Effect** selects an effect with the amount, size, speed, wind and pointer repulsion you specify.

For example, make a shortcut named **Start Firefly Hour**, add **Apply SZNS Scene**, and choose **Firefly Hour**. Then ask Siri to “Start Firefly Hour.” macOS exposes App Intents as actions for user-created shortcuts. [Apple’s App Shortcuts guide](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts)

## Build checks

The **Build SZNS** workflow builds both Debug and Release on macOS, checks the local signature, app icon and all six Shortcuts actions, checks that first launch displays a native settings window, and packages the app. The settings and geometry checks can also run directly on a Mac with Xcode command-line tools:

~~~~sh
swiftc SZNS/Scene.swift SZNS/DisplayGeometry.swift Tests/main.swift -o /tmp/szns-checks
/tmp/szns-checks
~~~~

### Publishing updates

For each app release, update the marketing version and build number in both Xcode configurations. A successful push to `main` publishes the universal **SZNS-macOS.zip** on [GitHub Releases](https://github.com/Tekwiz17/SZNS/releases). Put release notes in `releases/<version>.md` or let GitHub generate them. Published versions keep their original download.

The workflow checks both architectures with the binary path before `-verify_arch`. The live Dock test observes the accessibility shelf because the system can keep an invisible full-screen Dock input window. The pause test seeds a saved scene and starts the built app under a timeout. Recovery tests locate the backup by filename because filesystem ordering can vary.

For a hands-on check, move and resize the Dock, try its three orientations and auto-hide, and switch displays and Spaces. Open an app over the desktop to check both menu bar placement modes. Save a scene with a custom SVG, quit, reopen and apply it. Try a named shortcut and sleep/wake the Mac. Accessibility approval, real Dock animations and Siri voice invocation require an interactive Mac session.

Settings live in **~/Library/Application Support/SZNS/Preferences.json**. SZNS stores its scenes and imported bulb masks locally.

## License

[MIT](LICENSE).

