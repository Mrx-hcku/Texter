# Texter

Flutter messaging app — Appwrite backend (Auth + Database + Storage), Material 3, teal theme.

## Before pushing to GitHub

1. Open `lib/config/app_config.dart` and set your real **Unity Ads Game ID**
   (`UnityAdsConfig.androidGameId`) and set `testMode = false` before release.
2. Appwrite project/database IDs are already filled in from your setup:
   - Project: `6a8e7ddd00107e2b7857`
   - Database: `messgram_db`
   - Storage bucket: `texter_media`
3. **Do not commit your Appwrite API key anywhere** — it's only needed for the
   one-time Termux setup you already did, never inside the Flutter app itself
   (the app only uses the public Project ID, which is safe to ship).

## How the build works

The repo intentionally does **not** include the generated `android/` folder
(with binary Gradle wrapper files). The `build_apk.yml` workflow runs
`flutter create --platforms=android .` on every run to regenerate it, then
overlays `android_overrides/AndroidManifest.xml` (permissions + app label) on
top. This keeps the repo small and avoids committing binary files.

## Push to GitHub

```bash
git init
git add .
git commit -m "Texter initial commit"
git branch -M main
git remote add origin <your-repo-url>
git push -u origin main
```

The workflow runs automatically on push to `main`, or manually via the
Actions tab ("Run workflow"). The built APK appears under the workflow run's
**Artifacts** section as `texter-release-apk`.

## Ads design note

- The **"Sponsored" cards** in Group Chat / Channels are native content
  (title, image, description, button) pulled live from the `ads` collection
  in Appwrite — you manage these yourself from the Appwrite console (no code
  change needed to add/remove a sponsored campaign).
- **Unity Ads** is wired in separately (`ads_service.dart`) to show a real
  interstitial ad when a user opens a Group chat — this is your actual ad
  revenue source. Unity Ads doesn't support native in-feed cards without its
  heavier LevelPlay SDK, so the two are kept separate but both active.
