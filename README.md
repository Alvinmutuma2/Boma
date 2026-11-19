# Boma — ops console for Polaris + Viwanda

A separate PWA that lets you (and a trusted operator) run the admin work with
buttons instead of the Supabase SQL editor: see pending maker submissions,
confirm → list them, renew, reject, and monitor both Polaris and Viwanda.

## Deploy (its own repo, same Supabase)
1. Run `admin_schema.sql` in your Polaris Supabase SQL editor.
   **Change the passphrase** inside it first — find this line and set a long,
   random value:
   `insert into app_secrets(k,v) values ('admin','CHANGE-ME-to-a-long-random-passphrase')`
2. `config.js` already has your Supabase keys (the public one — safe).
3. Push this folder to a new GitHub repo, e.g. `Boma`, and turn on Pages:
   ```
   git init
   git add .
   git commit -m "Boma ops console"
   git branch -M main
   git remote add origin https://github.com/Alvinmutuma2/Boma.git
   git push -f origin main
   ```
   Live at `https://alvinmutuma2.github.io/Boma/`.

## Use
- Open it, enter the **passphrase** (it stays on that device for the session).
- **Overview** — Polaris shops, live makers, pending, lapsed, monthly run-rate, inquiries.
- **Pending** — each maker who submitted: tap **Confirm & list** (goes live 30 days;
  if their phone already has a listing it renews instead) or **Reject**.
- **Listings** — live/expiring/lapsed makers; **Renew 30 days** on any.
- **Inbox** — inquiries, mark resolved.

## Delegating
Give the person the URL + the passphrase. They can do everything above without
touching Supabase. To revoke, change the passphrase (one line in `app_secrets`).

## Honest security note
This is gated by one shared passphrase (pragmatic brute-admin). It's fine for a
small, trusted team. The upgrade when you want per-person logins + an audit trail
is Supabase Auth with an admin role — same screens, real accounts. Keep the
passphrase private; rotate it if it ever leaks.
