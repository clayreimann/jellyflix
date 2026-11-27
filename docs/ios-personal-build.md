# Building Jellyflix for your own iOS device

This guide is for contributors and testers who are **not** the Jellyflix
maintainer and want to run a development or beta build on their own iPhone or
iPad. You will sign the app with your own Apple account under your own bundle
ID, so it installs next to the App Store version instead of fighting with it.

The short version:

```bash
JELLYFLIX_TEAM_ID=ABCDE12345 \
JELLYFLIX_BUNDLE_ID=com.yourname.jellyflix \
JELLYFLIX_DISPLAY_NAME="Jellyflix Beta" \
  ios/scripts/personal_build.sh --install "My iPhone"
```

The rest of this page explains what you need and what the script does.

## Why not just press Run in Xcode?

The committed Xcode project is set up for the maintainer's release pipeline:

- bundle ID `com.ambark.jellyflix`, which belongs to the maintainer's team,
- manual signing with the fastlane match profile
  `match AppStore com.ambark.jellyflix`,
- the team ID as the placeholder `SENSITIVE_REPLACE_ME`, which CI fills in.

None of that can work with your account. These values are target-level
settings in `project.pbxproj`, so an `.xcconfig` file cannot override them, and
command-line overrides such as `PRODUCT_BUNDLE_IDENTIFIER=...` would also apply
to every CocoaPods framework in the build. The script therefore patches the
Runner project temporarily, builds, and restores the original files when it
exits, even if the build fails. Nothing ends up in `git status`, so there is
nothing to accidentally commit.

Using your own bundle ID also matters on devices that already have Jellyflix
from the App Store. If you install a build that reuses `com.ambark.jellyflix`,
the installer may report success while iOS keeps the App Store copy.

## Prerequisites

1. **A Mac with Xcode**, plus the Flutter stable SDK and CocoaPods
   (`brew install cocoapods` or `sudo gem install cocoapods`). Run
   `flutter doctor` and fix anything it reports for iOS.
2. **An Apple account signed in to Xcode** (Xcode > Settings > Accounts).
   - A free Apple ID works. It gives you a "Personal Team". Apps signed this way
     expire after 7 days and must be rebuilt, and you can have at most 3 such
     apps on a device at once.
   - A paid Apple Developer Program membership gives 1-year profiles and lets
     you register up to 100 devices per type.
3. **Your team ID**, a 10-character string such as `ABCDE12345`:
   - Paid account: [developer.apple.com/account](https://developer.apple.com/account)
     > Membership details.
   - Personal team: open `ios/Runner.xcworkspace` in Xcode, select the Runner
     target > Signing & Capabilities, choose your Personal Team, and read the
     `DEVELOPMENT_TEAM` value under Build Settings. Then discard the change
     with `git checkout ios/Runner.xcodeproj`.
4. **A bundle ID that is unique to you**, in reverse-DNS form, such as
   `com.yourname.jellyflix`. Automatic signing registers it for you on the
   first build.

## Prepare the device

1. Connect the device to the Mac with a cable, unlock it, and tap **Trust**.
2. **Turn on Developer Mode** (iOS/iPadOS 16 and later): Settings > Privacy &
   Security > Developer Mode, then restart the device and confirm. The switch
   only appears after the device has been connected to a Mac running Xcode.
   You can also open Xcode > Window > Devices and Simulators once to make it
   show up. Devices on iOS 15 or older do not have or need this setting.
3. On a paid team, the device must be in your team's device list. The script
   passes `-allowProvisioningDeviceRegistration`, so Xcode registers a
   connected device automatically.

## Build and install

From the repository root:

```bash
export JELLYFLIX_TEAM_ID=ABCDE12345
export JELLYFLIX_BUNDLE_ID=com.yourname.jellyflix
export JELLYFLIX_DISPLAY_NAME="Jellyflix Beta"   # optional, the home-screen name

ios/scripts/personal_build.sh
```

To avoid exporting the variables every time, put the three lines (without
`export`) in `ios/personal_build.env`. That file is git-ignored and the script
reads it automatically.

The script:

1. backs up `ios/Runner.xcodeproj/project.pbxproj` and `ios/Runner/Info.plist`,
2. changes the bundle ID, team, display name, and switches the Runner target to
   automatic signing with the "Apple Development" identity,
3. runs `flutter pub get`, `flutter build ios --release --config-only` and
   `pod install`,
4. runs `xcodebuild` with `-allowProvisioningUpdates` so Xcode creates the
   signing certificate and profile for you,
5. restores the two files.

The signed app ends up at
`build/ios-personal/Build/Products/Release-iphoneos/Runner.app`.

It builds the **Release** configuration on purpose. Flutter debug builds only
run while a debugger is attached, so a debug build installed this way would
crash as soon as you open it from the home screen.

Extra arguments after `--` go to `flutter build ios`, for example a version
number so you can tell builds apart:

```bash
ios/scripts/personal_build.sh -- --build-name=1.2.3 --build-number=42
```

### Installing with devicectl

Add `--install` to have the script install and launch the app. With no device
name, it lists the connected devices so you can pick one:

```bash
ios/scripts/personal_build.sh --install              # lists devices
ios/scripts/personal_build.sh --install "My iPhone"  # builds and installs
```

Or install an existing build yourself:

```bash
xcrun devicectl list devices
xcrun devicectl device install app --device "My iPhone" \
  build/ios-personal/Build/Products/Release-iphoneos/Runner.app
xcrun devicectl device process launch --device "My iPhone" com.yourname.jellyflix
```

`--device` takes the name, UDID or identifier shown by `devicectl list devices`.
Installing again with the same bundle ID updates the app in place and keeps
its data (server sign-in, downloads).

### Devices on iOS 16 or older

`devicectl` only talks to devices on iOS 17 and later. For older devices, such
as an iPad Air 2 on iPadOS 15, you need a different installer. First package the app as an `.ipa`:

```bash
mkdir -p build/ipa/Payload
cp -R build/ios-personal/Build/Products/Release-iphoneos/Runner.app build/ipa/Payload/
(cd build/ipa && zip -qr Jellyflix.ipa Payload)
```

Then install it with one of:

- **Apple Configurator** (free on the Mac App Store). Its command-line tool
  installs to the connected device:

  ```bash
  CFGUTIL="/Applications/Apple Configurator.app/Contents/MacOS/cfgutil"
  "$CFGUTIL" list
  "$CFGUTIL" install-app build/ipa/Jellyflix.ipa
  ```

  Or open Apple Configurator, double-click the device, and choose
  Add > Apps > Choose from my Mac.

- **ideviceinstaller** (`brew install ideviceinstaller`), then
  `ideviceinstaller -i build/ipa/Jellyflix.ipa`.

Recent Xcode versions also no longer install to these devices from the
Devices and Simulators window.

## First launch

With a paid team, the app opens straight away. With a free Personal Team, iOS
first asks you to trust the developer: Settings > General > VPN & Device
Management, select your Apple ID under Developer App, and tap **Trust**.

## Troubleshooting

- **"No Account for Team" or "No profiles for ... were found"**: sign in to
  Xcode > Settings > Accounts with the Apple ID that owns the team, and check
  `JELLYFLIX_TEAM_ID`.
- **"Failed to register bundle identifier" or "The app identifier cannot be
  registered"**: the bundle ID is taken by someone else. Pick another one.
- **The device does not appear in `devicectl list devices`**: unlock it,
  reconnect it, accept the Trust prompt, and check that Developer Mode is on.
  On iOS 16 and older, use Apple Configurator as described above.
- **The app opens and immediately closes**: you are running a debug build
  without a debugger attached. Use the Release build this script produces.
- **`pod install` crashes with an encoding error**: run it with
  `LANG=en_US.UTF-8`. The script sets this for you if `LANG` is unset.
- **The home-screen icon is blank**: iOS caches icons. Delete the app and
  install it again. If that does not help, check that the PNGs in
  `ios/Runner/Assets.xcassets/AppIcon.appiconset` are not empty files. They
  can be regenerated with `dart run flutter_launcher_icons`.
- **The app stopped opening after a week**: profiles from a free Personal Team
  expire after 7 days. Run the script again and reinstall.
- **Your working tree shows changes to `project.pbxproj` or `Info.plist`**:
  the script was killed before it could restore them (for example with
  `kill -9`). Run `git checkout ios/Runner.xcodeproj ios/Runner/Info.plist`,
  after making sure you have no other edits to keep in those files.

## Doing it by hand in Xcode

If you prefer the Xcode UI, open `ios/Runner.xcworkspace` after
`flutter pub get` and `pod install`. Select the Runner target > Signing &
Capabilities, turn on "Automatically manage signing", pick your team and
change the bundle identifier. Set the display name in the General tab. Then
choose Product > Scheme > Edit Scheme > Run > Build Configuration > Release and
run on your device. Remember to revert `ios/Runner.xcodeproj` and
`ios/Runner/Info.plist` before you commit, because those changes would break
the official release build.
