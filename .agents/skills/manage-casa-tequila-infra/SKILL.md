---
name: manage-casa-tequila-infra
description: Access, audit and safely operate the Casa de Tequila infrastructure across the local Home Assistant Samba shares and API plus its Firebase Cloud Messaging Google Cloud project. Use when configuring or deploying the alex_app HA custom integration, managing FCM registrations or credentials, checking Firebase billing/Analytics, accessing HA configuration files, restarting HA after validation, or troubleshooting Casa de Tequila push delivery.
---

# Manage Casa de Tequila Infrastructure

Operate from the `ha_app` repository. Keep all secrets outside the repository and redact command output before reporting it.

## Fixed inventory

- HA host: `192.168.0.150` (`homeassistant.local:8123` for the REST API)
- Samba user: `homeassistant`
- Samba shares: `config`, `local_apps`, `addons`, `app_configs`, `addon_configs`, `ssl`, `share`, `backup`, `media`
- Temporary Samba auth file: `/tmp/ha-samba-auth`, mode `0600`
- HA bearer token: Fish universal variable `home_assistant`; use `~/.agents/skills/home-assistant-local/scripts/ha.fish`
- Firebase/GCP project ID: `casa-de-tequila-push`
- Firebase project number: `774855380831`
- Android app ID: `1:774855380831:android:816e3ef2e2c2a0f70230ea`
- Android package: `com.al4xdev.casadetequila`
- FCM sender service account: `casa-de-tequila-ha-push@casa-de-tequila-push.iam.gserviceaccount.com`
- Private service-account key staging path: `/tmp/alex_app_fcm_service_account.json`, mode `0600`
- Private key destination in HA: `/config/alex_app_fcm_service_account.json`
- HA custom component source: `home-assistant/custom_components/alex_app_push`
- HA component destination: `/config/custom_components/alex_app_push`

The tracked Android `google-services.json` contains public Firebase identifiers, not the service-account private key. Never add the latter to Git.

## Prepare Samba access

If `/tmp/ha-samba-auth` is missing, ask the user to run the following Fish command. Put it in the clipboard with `wl-copy`; never receive or echo the password in chat.

```fish
read --silent --prompt-str='Senha Samba: ' samba_password
printf 'username = homeassistant\npassword = %s\n' "$samba_password" > /tmp/ha-samba-auth
chmod 600 /tmp/ha-samba-auth
set -e samba_password
```

Validate read access without exposing the credential:

```fish
smbclient -A /tmp/ha-samba-auth //192.168.0.150/config -c 'ls configuration.yaml'
```

Use `smbclient -A /tmp/ha-samba-auth`; never put the password directly in `-U`, command history, process arguments or logs.

## Safe HA configuration workflow

1. Query relevant current HA states before changes.
2. Download `configuration.yaml`, `automations.yaml` and any target component to a `mktemp -d` directory under `/tmp`.
3. Record SHA-256 checksums and keep the untouched backup until final verification.
4. Stage edited configuration under `/tmp`; do not edit live files in place.
5. Upload the custom component and `/tmp/alex_app_fcm_service_account.json` only after local tests pass.
6. Append exactly one top-level YAML block if absent:

```yaml
alex_app_push:
  service_account_file: /config/alex_app_fcm_service_account.json
```

7. Validate Home Assistant configuration before restart. Stop and restore the backup if validation fails.
8. Restart HA only when the requested operation requires loading Python/YAML changes.
9. Verify `/api/alex_app_push/snapshot` and `/api/alex_app_push/diagnostics`, HA logs and entity state after restart.

Do not overwrite unrelated user edits. Re-download and compare the live SHA immediately before each upload. Prefer moving replaced remote files to a timestamped `.bak` over deletion.

## Firebase operations

Set the project explicitly on every state-changing command:

```fish
gcloud config set project casa-de-tequila-push
```

Use Application Default Credentials for Firebase Management API calls:

```fish
set adc_token (gcloud auth application-default print-access-token)
```

Never print the token. Firebase configuration checks:

```fish
gcloud billing projects describe casa-de-tequila-push --format='json(projectId,billingEnabled,billingAccountName)'
curl -fsS -H "Authorization: Bearer $adc_token" \
  https://firebase.googleapis.com/v1beta1/projects/casa-de-tequila-push
curl -sS -H "Authorization: Bearer $adc_token" \
  https://firebase.googleapis.com/v1beta1/projects/casa-de-tequila-push/analyticsDetails
```

Expected baseline: `billingEnabled: false`; Firebase project has no Analytics property and `analyticsDetails` returns `404 NOT_FOUND`. The only Android Firebase dependency should be `firebase-messaging`; do not add Analytics, Crashlytics, Functions or Firestore.

The service account needs `roles/firebasecloudmessaging.admin`, not project Owner. Create a replacement key only when the current private key is missing or revoked:

```fish
gcloud iam service-accounts keys create /tmp/alex_app_fcm_service_account.json \
  --iam-account=casa-de-tequila-ha-push@casa-de-tequila-push.iam.gserviceaccount.com \
  --project=casa-de-tequila-push
chmod 600 /tmp/alex_app_fcm_service_account.json
```

After deploying and verifying a replacement, revoke its superseded service-account key. Never expose private key JSON in tool output.

## Release boundary

Use `$deploy-casa-tequila` for application releases. This skill owns infrastructure/configuration; the release skill owns tests, Android version environment variables, authenticated media upload, round-trip hash verification and the HA required-version switch.

For push cutover, preserve this ownership split:

- HA automations own schedules, deadlines and notification booleans.
- `alex_app_push` observes those booleans and sends FCM reconciliation snapshots.
- Android native code owns notification rendering and hourly WorkManager reconciliation.
- The WebView owns only the local passive trash notice.

Do not restore Companion `notify.mobile_app_*` calls, fallback endpoints, legacy IDs or dual notification paths.
