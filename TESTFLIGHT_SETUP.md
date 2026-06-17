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

Signing uses an **App Store Connect API key** — the runner creates the
distribution certificate and provisioning profile automatically, so you only
need the three API-key values (all created in a web browser, no Mac required).

Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | What it is | How to get it |
| --- | --- | --- |
| `ASC_KEY_ID` | App Store Connect API key ID | App Store Connect → Users and Access → **Integrations** tab → App Store Connect API → **+** to create a key. Give it the **App Manager** role. The Key ID is shown in the list. |
| `ASC_ISSUER_ID` | Issuer ID | Shown at the top of that same Integrations page. |
| `ASC_KEY_P8` | The `.p8` key file, base64-encoded | After creating the key, click **Download API Key** (you can only download it once). Then on any machine: `base64 -i AuthKey_XXXX.p8` and paste the output. |

> Direct link to create the key: https://appstoreconnect.apple.com/access/integrations/api

## GoogleCast (Chromecast) is currently removed

Chromecast support was removed so the project builds without any external
binary framework — the build is now self-contained and needs only Carthage
(VLCKit), which CI installs automatically. To add casting back later, re-add
`GoogleCast.xcframework` and the Cast code in `AppDelegate.swift` and
`VPlayerController.swift`.

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
