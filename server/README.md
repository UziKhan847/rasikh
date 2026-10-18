# Qiraah Arabiyyah marks server

The app's optional sync for **Hifz marks** (mark books, recitation sessions,
word marks, fixes and comments) runs on a self-hosted
[PocketBase](https://pocketbase.io), pinned to the version in `PB_VERSION`
(**0.40.5**). Everything about the server lives in this folder:

| Path | What |
|---|---|
| `pb_migrations/` | Schema **and API rules** as code — collections, fields, indexes, batch/rate-limit settings |
| `pb_hooks/hifz.pb.js` | Share-code and member routes, the stale-write (409) guard, account-deletion anonymising, nightly pruning |
| `pb_public/delete-account.html` | Web page to delete an account (Google Play requires one) |
| `deploy/` | systemd unit and Caddyfile |
| `dev.sh` | Download the pinned binary and run locally |

Accounts are **username + password**; an email is optional and only used for
password reset. Nothing is synced until someone signs in in the app.

## Data model in one paragraph

A **book** is one reciter's marks. It has an `owner` and lists of `listeners`
(may mark) and `checkers` (may read and comment). `sessions`, `marks`,
`mark_fixes` and `mark_comments` each belong to a book; a fix is its own row so
that a listener fixing a mark and its author editing the comment can't
overwrite each other. Rows carry `client_updated` (last-writer-wins clock) and
`deleted` (tombstone — rows are never hard-deleted through the API). Marks are
keyed `(surah, ayah, word)` in the 15-line muṣḥaf's word numbering
(`word_scheme = "mushaf15"`), shared by the Madani and Indo-Pak texts.

## Run locally

```sh
server/dev.sh superuser you@example.com 'a-long-password'   # dashboard login
server/dev.sh                                               # http://127.0.0.1:8090
```

Point the app at it: Hifz → Account & sync → Sign in → *Server address*
(`http://10.0.2.2:8090` from the Android emulator), or build with
`--dart-define=QIRAAH_SYNC_URL=…`.

**Integration tests** (the deployed rules and hooks, end to end):

```sh
PB_DATA=/tmp/pbtest server/dev.sh superuser admin@example.com admin-pass-123
PB_DATA=/tmp/pbtest server/dev.sh &
flutter test test/server --dart-define=PB_URL=http://127.0.0.1:8090 \
  --dart-define=PB_ADMIN=admin@example.com --dart-define=PB_ADMIN_PASS=admin-pass-123
```

Run them before every PocketBase upgrade.

## Deploy on a VPS (Debian/Ubuntu)

1. **DNS:** an `A`/`AAAA` record for e.g. `marks.example.com` → the VPS.
2. **User and files:**
   ```sh
   sudo useradd --system --home /opt/qiraah-marks --shell /usr/sbin/nologin qiraah
   sudo mkdir -p /opt/qiraah-marks/pb_data
   # copy pb_migrations/ pb_hooks/ pb_public/ into /opt/qiraah-marks/
   VER=$(cat server/PB_VERSION)
   curl -fLO https://github.com/pocketbase/pocketbase/releases/download/v$VER/pocketbase_${VER}_linux_amd64.zip
   sudo unzip pocketbase_${VER}_linux_amd64.zip pocketbase -d /opt/qiraah-marks
   echo "PB_ENCRYPTION_KEY=$(openssl rand -hex 16)" | sudo tee /opt/qiraah-marks/.env
   sudo chown -R qiraah:qiraah /opt/qiraah-marks && sudo chmod 600 /opt/qiraah-marks/.env
   ```
   Keep a copy of `PB_ENCRYPTION_KEY` somewhere safe — it encrypts the stored
   SMTP/S3 credentials.
3. **Service:** `sudo cp deploy/pocketbase.service /etc/systemd/system/qiraah-marks.service`,
   then `sudo systemctl enable --now qiraah-marks`. Migrations apply on start.
4. **TLS:** install Caddy, put `deploy/Caddyfile` (with your domain) at
   `/etc/caddy/Caddyfile`, `sudo systemctl reload caddy`.
5. **Admin:** `sudo -u qiraah /opt/qiraah-marks/pocketbase superuser upsert you@example.com '…' --dir=/opt/qiraah-marks/pb_data`,
   then open `https://marks.example.com/_/`.
6. **Firewall:** allow 80 and 443 only (and SSH).

### Dashboard settings checklist

The migration already turns on the **Batch API** (200 requests) and the
**rate limiter** (strict on sign-in, sign-up and share codes). Then, under
Settings:

- [ ] **Application → Superuser IPs:** your own IP(s) only.
- [ ] **Superusers collection:** enable MFA/OTP for the superuser.
- [ ] **Application → User IP proxy headers:** `X-Forwarded-For` (behind Caddy).
- [ ] **Backups:** daily (e.g. `0 3 * * *`), keep 7; and copy them off the VPS
      (S3-compatible storage, or `rsync` the `pb_data/backups` folder).
- [ ] **Mail (SMTP):** only needed once someone adds a recovery email
      (password resets). Until then, reset passwords from the dashboard:
      Collections → users → the user → set a new password.
- [ ] Try a **restore** of a backup on a scratch machine once.

## Operating

- **Logs:** `journalctl -u qiraah-marks -f`; request logs in the dashboard.
- **Upgrading PocketBase:** read its release notes (it is pre-1.0; breaking
  changes happen), update `PB_VERSION`, run the integration tests locally
  against the new binary, then swap the binary on the VPS and restart.
- **Schema changes:** add a new file to `pb_migrations/` (never edit an applied
  one); it runs on the next start.
- **Account deletion:** in the app, or at
  `https://marks.example.com/delete-account.html` (the URL for the Play
  Console's data-deletion field). The user's own books go with them; what they
  wrote in other people's books stays there, anonymised.
- **Retention:** deleted rows (tombstones) are pruned after 90 days; expired
  share codes nightly. Everything else stays until its owner deletes it.
