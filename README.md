# Ledger (iOS)

Native SwiftUI client for [Ledger](https://ledger.nailfec.com). Money is integer cents of CNY. The database is the contract — see `ledger-supabase`.

## Requirements

- macOS with Xcode that ships the **iOS 27 SDK**
- Deployment target: **iOS 27.0** (no fallbacks for earlier OS versions)
- A running Supabase project with the Ledger migrations applied

## Setup

1. Open `Ledger.xcodeproj` on a Mac.
2. Xcode resolves [supabase-swift](https://github.com/supabase/supabase-swift) via Swift Package Manager.
3. Copy secrets:

```bash
cp Ledger/Secrets.example.plist Ledger/Secrets.plist
```

Edit `Secrets.plist` and set `SUPABASE_URL` and `SUPABASE_ANON_KEY`. If secrets are missing, the app shows a setup screen.

4. Enable **Sign in with Apple** for the App ID `com.nailfec.ledger` in the Apple Developer portal (required whenever Google sign-in is also offered).
5. In the Supabase dashboard, allow the redirect URL `ledger://auth-callback` for OAuth.

## App Store checklist

| Item | Value |
| --- | --- |
| Privacy policy URL | https://ledger.nailfec.com/privacy |
| Account deletion URL | https://ledger.nailfec.com/delete-account |
| Encryption export compliance | `ITSAppUsesNonExemptEncryption` = **false** (no non-exempt encryption) |
| Sign in with Apple | Entitlement enabled; in-app Sign in with Apple next to email and Google |
| In-app account deletion | Settings → Delete account → removes Storage objects under `attachments/{userId}/…`, then calls `delete_account()` |

## Architecture notes

- Tabs: Activity, Insights, Accounts, Settings. **New entry** is a bottom action bar (Liquid Glass), not a tab.
- Soft-delete only (`deleted_at`). Do not hard-delete ledger rows.
- Realtime subscriptions on `entries` and `accounts`.
- Attachments: images and PDF, max 10 MB, path `{userId}/{entryId}/{file}` in the `attachments` bucket.

## Bundle

- Display name: **Ledger**
- Bundle identifier: `com.nailfec.ledger`
- URL scheme: `ledger` → host `auth-callback` (`ledger://auth-callback`)
