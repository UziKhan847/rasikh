# Rāsikh downloads on the Hetzner server

The printed muṣḥafs (New Madani first) are served as plain static files by
the nginx that already runs in podman:

```
https://dl.example.com/catalog.json        what can be downloaded (no-cache)
https://dl.example.com/catalog.json.sig    its Ed25519 signature
https://dl.example.com/packs/<name>.zip    the packs (never change; cached for good)
```

## How it stays safe

The app trusts **the signature**, not the server. Even someone who takes over
the server can't get a phone to install anything:

- **Signed catalog.** The app believes `catalog.json` only if it is signed by
  the private key in `~/.config/rasikh/pack-signing.key`. The app has the
  public key built in, and the private key never goes on the server.
- **No rollback.** The app remembers the newest catalog date it has seen and
  refuses an older catalog.
- **Checked packs.** Every pack is checked against the catalog's exact size
  and SHA-256. A pack is refused if:
  - it is a byte longer or shorter than listed;
  - a single bit differs;
  - it holds any file name outside a fixed list (no `..`, no absolute paths,
    nothing but page images and the muṣḥaf's own files).

  A pack is unpacked aside and moved into place only once it has passed every
  check.
- **https only.** The app won't download over plain http.

The server's part is to be boring:
- static files, read-only, GET and HEAD only;
- no listings and no other paths;
- rate-limited;
- logs that keep no whole IP address.

## 1. DNS

At your DNS provider, add a record for the subdomain, pointing to the server:

```
dl.example.com.   A      <server IPv4>
dl.example.com.   AAAA   <server IPv6>     (if the server has one)
```

Check it: `dig +short dl.example.com` shows the server's address.

## 2. The files' folder on the server

Make one folder for the downloads, owned by an ordinary user that uploads
(not root), and readable by everyone:

```bash
sudo adduser --disabled-password --gecos "" deploy     # or use your own user
sudo mkdir -p /srv/rasikh-dl/packs
sudo chown -R deploy:deploy /srv/rasikh-dl
sudo chmod 755 /srv/rasikh-dl /srv/rasikh-dl/packs
```

Let `deploy` log in only with your SSH key:

```bash
sudo mkdir -p /home/deploy/.ssh
sudo cp ~/.ssh/authorized_keys /home/deploy/.ssh/
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

## 3. The certificate (Let's Encrypt)

The nginx config refers to the certificate, so nginx won't start with it until
the certificate exists. Get the certificate first.

**If you already use certbot** for the other site, add this name the same way
you did there, and skip to step 4.

**Otherwise**, use certbot on the host, with nginx answering its check from a
folder:

1. Install certbot and make the check folder:

   ```bash
   sudo apt install certbot
   sudo mkdir -p /var/www/certbot
   ```

2. Add these two mounts to the nginx container. Where depends on how it is
   started: the `podman run` line, the compose file, or the quadlet `.container`
   file.

   ```
   -v /var/www/certbot:/var/www/certbot:ro
   -v /etc/letsencrypt:/etc/letsencrypt:ro
   ```

3. For now, put in only the port 80 part of `rasikh-dl.conf`: the first
   `server { listen 80; … }` block, with `dl.example.com` replaced by your
   subdomain. Reload nginx.

4. Get the certificate:

   ```bash
   sudo certbot certonly --webroot -w /var/www/certbot -d dl.example.com
   ```

5. Renewal is automatic (certbot's timer). Make nginx pick up each new
   certificate:

   ```bash
   echo -e '#!/bin/sh\npodman exec <nginx-container> nginx -s reload' |
     sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
   sudo chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
   sudo certbot renew --dry-run
   ```

   (If nginx runs in rootless podman under another user, run that `podman exec`
   as that user: `sudo -u <user> XDG_RUNTIME_DIR=/run/user/<uid> podman exec …`.)

## 4. nginx

1. In `rasikh-dl.conf`, replace `dl.example.com` (3 places) with your
   subdomain.
2. Put the file in the container's `conf.d/` (mounted or copied, as your other
   site's config is). It holds `limit_req_zone`, `map` and `log_format`, which
   belong in the `http` block. Files in `conf.d/` are included there by the
   official image.
3. Mount the download folder **read-only**:

   ```
   -v /srv/rasikh-dl:/srv/rasikh-dl:ro
   ```

4. Check, then reload:

   ```bash
   podman exec <nginx-container> nginx -t
   podman exec <nginx-container> nginx -s reload
   ```

Changing mounts needs the container to be recreated, not just restarted. With
a quadlet: `systemctl --user daemon-reload` (or without `--user` if rootful),
then restart the service.

## 5. Publish the New Madani

Do this on your computer, never on the server. The packs and the signed
catalog are already built in `build/packs/`.

```bash
# (only after a change: python3 tool/packs/build_packs.py newmadani 2
#  and then: dart run tool/packs/sign_catalog.dart sign)
RASIKH_DL_SSH=deploy@<server> RASIKH_DL_URL=https://dl.example.com tool/packs/upload.sh
```

The script:
1. checks the signature;
2. uploads the packs that aren't on the server yet;
3. checks every pack on the server against the catalog's SHA-256;
4. only then swaps in the new catalog and its signature.

## 6. The app

Build with the address:

```bash
flutter build apk --split-per-abi --dart-define=RASIKH_PACKS_URL=https://dl.example.com
```

The Linux build takes the same `--dart-define`. Alternatively, put the address
as the default of `kPacksBaseUrl` in `lib/core/packs/pack_catalog.dart`, so
every build has it.

## 7. Check from outside

Run these from your computer, not from the server:

```bash
D=https://dl.example.com
curl -sI $D/catalog.json | head -1                 # 200
curl -sI $D/packs/newmadani-low-v1.zip | head -1   # 200
curl -s -o /dev/null -w '%{http_code}\n' -r 0-99 $D/packs/newmadani-low-v1.zip   # 206 (resume works)
curl -s -o /dev/null -w '%{http_code}\n' $D/                  # 404
curl -s -o /dev/null -w '%{http_code}\n' $D/packs/            # 404
curl -s -o /dev/null -w '%{http_code}\n' -X POST $D/catalog.json   # 403
curl -s -o /dev/null -w '%{http_code}\n' http://dl.example.com/catalog.json  # 301
```

Then grade the TLS setup at https://www.ssllabs.com/ssltest/; expect an A.

## Security checklist for the server

### Logging in
- [ ] SSH: keys only, no root login. In `/etc/ssh/sshd_config.d/hardening.conf`:

  ```
  PasswordAuthentication no
  KbdInteractiveAuthentication no
  PermitRootLogin no
  ```

  Then run `sudo systemctl reload ssh`. Keep your current session open and
  test a new login before closing it.
- [ ] fail2ban for SSH: `sudo apt install fail2ban`. Its default jail covers
  sshd.

### Firewall
- [ ] Open only 22, 80 and 443:

  ```bash
  sudo ufw default deny incoming
  sudo ufw allow OpenSSH
  sudo ufw allow 80,443/tcp
  sudo ufw enable
  ```

- [ ] **Podman and ufw.** Rootful podman publishes ports through its own
  firewall rules, which can go around ufw. So check from outside that nothing
  else answers: from your computer, run `nmap -Pn <server IP>`; only 22, 80
  and 443 should be open.
- [ ] The Hetzner firewall as a second wall. It lives in Robot (dedicated
  servers) or the Cloud Console (cloud servers). Allow TCP 22, 80 and 443 in,
  and allow established connections back. On dedicated servers, also allow
  TCP 32768–65535 in, for replies.

### Updates and monitoring
- [ ] Security updates on their own: `sudo apt install unattended-upgrades`,
  then `sudo dpkg-reconfigure -plow unattended-upgrades`.
- [ ] The nginx image updated now and then: `podman pull
  docker.io/library/nginx:stable`, then recreate the container. Podman's
  auto-update can do this for a quadlet.
- [ ] Traffic watched. One full New Madani download is 232 MB (both
  qualities); most phones take only the 85 MB one.
  - Install vnstat (`sudo apt install vnstat`), then check `vnstat -m`.
  - Hetzner cloud servers include 20 TB a month in the EU.
- [ ] The download log stays small and anonymised. `logrotate` in the image
  handles it; addresses are logged with the last part zeroed
  (`203.0.113.0`).

### Keys and publishing
- [ ] The signing key is backed up off this computer (in a password manager):
  `~/.config/rasikh/pack-signing.key`. Without it no new catalog can be signed
  for the apps already installed. If it ever leaks, make a new one and ship an
  app update with the new public key.
- [ ] Never on the server: the signing key, the repo, or build tools. The
  server only ever receives finished files.
- [ ] Never change a published pack. A fix is a new version
  (`build_packs.py newmadani 2`), so a new file name. The upload script
  refuses to overwrite a pack.

## Tuning

`limit_conn 3` allows three downloads at once per address, and 5 requests a
second per address (10 at once), then "429 too many requests". The app
downloads one file at a time.

Many phones on one mobile carrier can share one address. If people report
downloads failing at busy times, raise `limit_conn` (e.g. to 10).

## Try it on your computer

`test/packs_download_test.dart` has an end-to-end test against this exact
config:
1. Start `docker.io/library/nginx:stable` in podman with:
   - `rasikh-dl.conf`;
   - a self-signed EC certificate in `live/dl.example.com/`;
   - `build/packs` mounted at `/srv/rasikh-dl`;
   - published on port 18443.
2. Run:

   ```bash
   RASIKH_DL_TEST=https://localhost:18443 flutter test test/packs_download_test.dart
   ```

The test downloads the real low-quality pack, checks it, installs it and opens
its 604 pages.
