# Automated TestFlight builds

This repo includes a GitHub Actions pipeline (`.github/workflows/testflight.yml`)
that builds the app on a macOS runner and uploads it to TestFlight via fastlane
(`fastlane/Fastfile`). Once configured, every push to the build branch — or a
manual run from the **Actions** tab — produces a TestFlight build with no Mac
work on your side.

> **Heads up:** the one-time setup below has ~6 steps, several of which need your
> Mac to export signing assets. If you just want the app on your phone *today*,
> archiving once in Xcode (Product → Archive → Distribute) is faster. Use this
> pipeline for repeatable builds afterwards.

## GitHub secrets to add

Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | What it is | How to get it |
| --- | --- | --- |
| `ASC_KEY_ID` | App Store Connect API key ID | App Store Connect → Users and Access → Integrations → App Store Connect API → create a key (Admin or App Manager). |
| `ASC_ISSUER_ID` | Issuer ID | Shown on the same API keys page. |
| `ASC_KEY_P8` | The `.p8` key file, base64-encoded | After creating the key, download the `.p8` once, then: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |
| `BUILD_CERTIFICATE_BASE64` | Your Apple **Distribution** certificate as a `.p12`, base64-encoded | Xcode → Settings → Accounts → Manage Certificates, or Keychain Access → export the "Apple Distribution" cert + private key as `.p12`. Then `base64 -i dist.p12 \| pbcopy` |
| `P12_PASSWORD` | Password you set when exporting the `.p12` | You choose it during export. |
| `PROVISIONING_PROFILE_BASE64` | An **App Store** provisioning profile for `fr.meublin.IPTV`, base64-encoded | developer.apple.com → Profiles → create an App Store distribution profile, download it, then `base64 -i profile.mobileprovision \| pbcopy` |
| `PROVISIONING_PROFILE_NAME` | The exact name of that profile | Shown in the Apple Developer portal (e.g. "IPTV App Store"). |
| `KEYCHAIN_PASSWORD` | Any random string | Used to create a throwaway keychain on the runner. Make one up. |
| `GOOGLECAST_SDK_URL` | Direct download URL to the GoogleCast iOS SDK zip | The `GoogleCast.xcframework` is gitignored. Either set this URL, **or** commit the framework to the repo and delete the "Fetch GoogleCast SDK" step in the workflow. |

## Running it

- **Automatic:** push to `claude/iptv-playlist-platform-kusumt` (change this to
  `main` in the workflow once merged).
- **Manual:** GitHub → **Actions** tab → **TestFlight** → **Run workflow**.

After the run finishes, the build appears in App Store Connect → your app →
**TestFlight** (allow ~10–15 min for Apple to finish processing). Add yourself
under **Internal Testing** to install via the TestFlight app.

## First-time only

Before the first upload succeeds, create the app record in App Store Connect:
**Apps → + → New App**, bundle ID `fr.meublin.IPTV`.
