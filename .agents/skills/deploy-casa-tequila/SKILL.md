---
name: deploy-casa-tequila
description: Build, test and transactionally publish the Casa de Tequila Android application through the local Home Assistant. Use when releasing, deploying, updating, rebuilding or publishing a new app version or when asked to place the current application package in HA for mandatory in-app updates.
---

# Deploy Casa de Tequila

Run the bundled Fish script from the `ha_app` repository. It is the only supported release path.

```fish
~/.agents/skills/deploy-casa-tequila/scripts/deploy.fish 1.6.0
```

The script derives a monotonic `versionCode` from the requested semantic version, exports both version values only through `CASA_TEQUILA_VERSION_NAME` and `CASA_TEQUILA_VERSION_CODE`, runs the complete Playwright suite, builds the Android artifacts, uploads a versioned copy to authenticated HA media, downloads it back and compares SHA-256, then updates the HA media ID and required version in that order. It never edits a version file in the repository.

## Safety contract

- Require the Fish universal variable `home_assistant`; never print or copy its value.
- Never publish the required version before the uploaded file passes the round-trip hash check.
- On any failure, restore any HA helper already changed. Version metadata is ephemeral and disappears with the script process.
- Do not add fallback, bypass, compatibility or “continue anyway” behavior.
- Keep the previous versioned media file; it is the rollback artifact.
- Use `.mp4` only as the HA media transport extension. The bytes remain the signed Android package and Android validates package name, version and signing certificate before installation.
- Treat a successful script exit and its final JSON report as the release checkpoint.

## Home Assistant contract

- Required version: `input_text.alex_app_apk_versao_atual`
- Versioned media ID: `input_text.alex_app_apk_media_id`
- Media folder: `media-source://media_source/local/alex_app`

The Android gate consults these two helpers before constructing its WebView. A network failure, invalid value or version mismatch keeps all widgets and commands disconnected.

If a release fails, report the failing stage and leave the HA-required version unchanged.
