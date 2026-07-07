# Release Guide — Scythe Companion Android APK

This runbook walks you (Matos) through cutting a signed release APK
and publishing it on the GitHub Releases page so friends can install
it without rebuilding. **Models never touch the keystore or push
binaries** (AGENTS.md C1 / C2) — you run this script yourself.

**Total time:** ~15 minutes the first time (keystore creation included),
~3 minutes per subsequent release.

---

## What you need

- WSL with Flutter 3.44.4 + Android SDK + JDK 17/21 (already set up
  per DECISIONS E3).
- A `gh` CLI authenticated against `Matos182/scythe-companion` (used
  by the upload step).
- A backup location for the keystore (1Password / Bitwarden / an
  encrypted USB stick). **If you lose the keystore, you cannot push
  updates to anyone who already installed v0.4.0** — Play Store and
  GitHub Releases both require matching signatures for upgrades.

---

## 1. Create the keystore (one-time only)

```bash
# Pick a strong password and store it in your password manager.
# The alias "scythe" is what you'll reference in key.properties.
mkdir -p ~/keystores
cd ~/keystores
keytool -genkey -v \
    -keystore scythe-companion-release.jks \
    -keyalg RSA -keysize 2048 -validity 9125 \
    -alias scythe \
    -storepass '<PICK_A_PASSWORD>' \
    -keypass  '<PICK_A_PASSWORD>' \
    -dname "CN=Matos,O=Scythe Companion,C=PT"
```

- `-validity 9125` = 25 years (Android requires ≥ 25 years for APKs
  uploaded to the Play Store; harmless for direct sideloading).
- The password is asked interactively if you omit `-storepass`.
  Same password for `-storepass` and `-keypass` is fine — Android
  tooling expects that pattern.

**Back up `scythe-companion-release.jks` and the password somewhere
safe.** Outside the repo. Outside `~/keystores` ideally.

---

## 2. Write `android/key.properties` (one-time per machine)

```bash
cd ~/dev/scythe-companion   # or your worktree path
cp android/key.properties.example android/key.properties
$EDITOR android/key.properties
```

Fill in:

```properties
storeFile=/home/matos/keystores/scythe-companion-release.jks
storePassword=<the password from step 1>
keyAlias=scythe
keyPassword=<the password from step 1>
```

`storeFile` can be relative to the `android/` dir if you prefer
(`storeFile=../keystores/scythe-companion-release.jks`).

This file is gitignored — verify with `git check-ignore
android/key.properties` (should print the path).

---

## 3. Bump the version

In `pubspec.yaml`:

```yaml
version: 0.4.0+1
#            ^    ^
#            |    +-- versionCode (Android: monotonically increasing int)
#            +------- versionName (user-visible in Settings → Apps)
```

When shipping v0.4.1:

```yaml
version: 0.4.1+2   # bump the +N every release even if versionName doesn't change
```

Conventions:

- `versionName` follows semver loosely — `MAJOR.MINOR.PATCH` for
  user-visible changes. Phase 4 starts at `0.4.0` (multiplayer ship).
- `versionCode` is a monotonic int for the Play Store / Android
  package manager. **Bump it on every release**, even for metadata
  changes. The easiest scheme: start at 1 and bump by 1 each time.

After editing `pubspec.yaml`, run `flutter pub get` to refresh
`.flutter-plugins-dependencies` (Flutter reads `version` on pub get).

---

## 4. Build the signed release APK

```bash
cd ~/dev/scythe-companion   # or worktree
flutter clean
flutter pub get
flutter build apk --release
```

Output:

```
build/app/outputs/flutter-apk/app-release.apk
```

Expected size: 15–25 MB (R8 strips unused code; with our 4 plugins
it's well under 30 MB). If the size balloons past 40 MB, something
shipped a fat asset — check `pubspec.yaml`.

### Verifying the signature

```bash
$ANDROID_HOME/build-tools/<version>/apksigner verify \
    --verbose build/app/outputs/flutter-apk/app-release.apk
```

Should print `Verified using v2 scheme (APK Signature Scheme v2): true`
and list your certificate's SHA-256 fingerprint. The fingerprint is
stable across rebuilds as long as the keystore + alias are unchanged.

---

## 5. (Optional) Test the APK on your phone before publishing

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.matos.scythe_companion/.MainActivity
```

Walk through:

1. Home menu opens.
2. Tap **Create Room** → form → Connect → create a real room against
   your dev server.
3. Tap **Join Room** → typed code → form.
4. Open **Settings** → confirm server URL round-trips.
5. Kill the app from Recents → reopen → rejoin prompt fires
   (T3.3 rejoinSavedSession).

If anything crashes immediately, check `adb logcat | grep -i flutter`
— most R8 issues surface as `NoSuchMethodError` referencing a
removed class. Add a `-keep class <missing> { *; }` line to
`android/app/proguard-rules.pro`, rebuild, retest.

---

## 6. Create the GitHub Release

```bash
cd ~/dev/scythe-companion
git tag -a v0.4.0 -m "v0.4.0 — first multiplayer-ready release"
git push origin v0.4.0
gh release create v0.4.0 \
    build/app/outputs/flutter-apk/app-release.apk \
    --title "v0.4.0 — first multiplayer-ready release" \
    --notes-file - <<'EOF'
# Scythe Companion v0.4.0

First release with online rooms (turn order + turn timers). Calculator
is the same offline tool as v0.3.x.

## Install

1. Download `scythe-companion-v0.4.0.apk` below.
2. On your phone: Settings → Security → Install unknown apps →
   allow your browser (Chrome/Firefox) to install APKs.
3. Open the downloaded file → Install.
4. Open **Scythe Companion** → tap the gear icon → paste your server
   URL (Matos will share it, e.g. `https://scythe.example.com`).
5. **Create** a room → share the room code (or the QR) with your
   friends → they **Join**.

If you had v0.3.x installed, uninstall it first (different signing
key — Android won't auto-upgrade across keys).

## What's new

- Multiplayer rooms with turn order and per-player timers.
- Local "your turn" notification when backgrounded.
- Server address is runtime-configurable (no APK rebuild).
- QR-based room joining.
EOF
```

`gh release create` uploads the APK as a release asset (under the
100 MB limit — APKs are usually 15–25 MB so no issue). The release
page URL is `https://github.com/Matos182/scythe-companion/releases/tag/v0.4.0`.

### If `gh` isn't authenticated

```bash
gh auth login   # follow the prompts — browser flow is fine
gh auth status  # confirm "Logged in to github.com as Matos182"
```

---

## 7. Hand the URL to friends

Send the release link in your group chat. Suggested copy:

> Install Scythe Companion v0.4.0:
> https://github.com/Matos182/scythe-companion/releases/latest
>
> After install, set the server URL to **`<your URL>`** in the app
> gear icon. Then create a room and share the QR/code.

The `/releases/latest` URL always points to the highest tagged
release, so future updates keep the same link.

---

## Appendix A — Versioning policy

| Bump | When | Examples |
|---|---|---|
| **MAJOR** (0.x → 1.0) | First version you trust friends to install without caveats | 0.4.0 → 1.0.0 |
| **MINOR** (x.1) | New user-facing feature (e.g. score history, factions) | 0.4.0 → 0.5.0 |
| **PATCH** (x.x.1) | Bug fix / polish that doesn't add a feature | 0.4.0 → 0.4.1 |

Bump `versionCode` (the `+N` suffix) on **every** release, even
PATCH bumps with the same versionName. Android's package manager
refuses to install a new APK with a `versionCode` ≤ the old one.

## Appendix B — Common R8 / proguard problems

| Symptom | Fix |
|---|---|
| App crashes on launch with `ClassNotFoundException` | Add `-keep class <fqn> { *; }` to `proguard-rules.pro` |
| App crashes on first plugin call (`NoSuchMethodError`) | Same — the plugin's own keep rules missed something |
| `java.lang.NullPointerException` from Flutter engine | Make sure `-keep class io.flutter.** { *; }` is present (it is, by default) |
| Release APK bigger than debug APK | `shrinkResources true` is failing — check `build/app/outputs/mapping/release/` for unused-resource warnings |

If a new plugin is added and breaks release, the fastest path is
`-keep class <plugin.package>.** { *; }` then narrow it down once
the app boots.

## Appendix C — Where the keystore + passwords live

| Secret | Location | Notes |
|---|---|---|
| `scythe-companion-release.jks` | `~/keystores/` on your dev machine | Backed up to 1Password / encrypted USB |
| Keystore password | 1Password (or your password manager) | Same as key password |
| `android/key.properties` | `~/dev/scythe-companion/android/` | gitignored — verify with `git check-ignore` |

**None of these are committed to the repo.** Models never see them
(C2). The CI workflow (T4.1) builds a debug APK only; release
APKs are your responsibility per C1.

If you need to set up CI release builds later, the recommended path
is a GitHub Actions secret named `ANDROID_KEYSTORE_BASE64` (the
base64-encoded `.jks` file) plus `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` — the workflow writes
`key.properties` at runtime from those env vars. Out of scope for
v0.4.0; revisit if/when automated releases become useful.