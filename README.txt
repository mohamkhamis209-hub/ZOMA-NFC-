ZOMA Smart Card - Full GitHub Pages + Supabase build

1) Upload the CONTENTS of this folder to the root of the GitHub repository. index.html must be in repository root.
2) The project site is configured for:
   https://mohamkhamis209-hub.github.io/ZOMA-NFC/
3) Supabase SQL:
   Open Supabase > SQL Editor and run sql/schema.sql.
   If you already have the old ZOMA schema, first compare existing columns/tables. The script is mostly idempotent but is intended for a clean ZOMA database.
4) Supabase Auth:
   - Create an admin Auth user.
   - Add that Auth user's UUID to public.admins, e.g.:
     insert into public.admins(id,username,full_name,role) values ('AUTH-UUID','Mohamed','Mohamed','owner');
   - Disable email confirmation for local/demo customer testing, or configure email delivery for production.
5) Browser customer login:
   Registration creates a synthetic Supabase Auth email from phone (phone_20XXXXXXXXXX@zoma.local). Users can log in using phone or Card ID because zoma_get_login_email resolves it.
6) NFC:
   Actual writing uses Web NFC. This requires a supported Android/Chrome device and an HTTPS page. On unsupported devices the site reports the limitation.
   NFC stores ONLY the permanent card URL, not passwords or personal data.
7) QR:
   There is intentionally NO QR generator in this site. Copy the permanent card URL and turn it into QR with any external QR service, as requested.
8) Public card link format:
   https://mohamkhamis209-hub.github.io/ZOMA-NFC/activation.html?id=ZOMA-XXXXXX
   Before activation it shows the secure setup flow. After activation it goes to the public card profile.
9) Production hardening:
   Use Supabase publishable key in the browser, keep secret/service_role keys off the frontend, configure stronger anti-abuse rules, email/phone verification, backups, and custom domain before public launch.


FIX 2026-09-12: Removed references to nonexistent designs.image_url/designs.image columns; customer order creation uses zoma_create_order RPC; admin orders query uses explicit existing columns.
