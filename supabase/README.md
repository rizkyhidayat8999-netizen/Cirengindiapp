# Cireng Indi Dedicated Supabase

Live project:
- Ref: `kzvlelcngcxgjsvtvsnj`
- URL: `https://kzvlelcngcxgjsvtvsnj.supabase.co`
- Region: `ap-southeast-1`

The two Android applications use the same Cireng Indi backend:
- Member: `com.cirengindi.member`
- Owner: `com.cirengindi.owner`

Active Edge Functions:
- `member-auth` — public register/login/forgot with internal validation and rate limiting
- `cirengindi-mobile-api` — public bootstrap plus JWT-protected Member actions
- `cirengindi-owner-api` — JWT-required and staff-role-protected Owner actions

Production data currently seeded:
- 4 categories
- 31 products
- 42 product variants
- 4 banners
- 12 rewards
- 3 couriers
- COD only
- Delivery + Pick Up checkout
- Classic / Silver / Gold / Platinum member levels

Security:
- No service-role key is present in either APK.
- Member and Owner access is separated by Auth + RLS + staff checks.
- Anonymous execution has been removed from all Cireng Indi SECURITY DEFINER RPCs.
- Courier contact data is stored separately and is not publicly readable.
- Storage bucket `cirengindi-products` is public-read / staff-write.
- Current product images are bundled inside Member APK, so the app does not depend on Storage objects being uploaded before first test.

Important production gates:
1. Create a real Owner Auth user and insert that user into `staff_profiles` with role `owner`.
2. Add `https://cirengindi.com/reset-password` to Supabase Auth redirect URLs and publish the route.
3. Run end-to-end tests using real Member + Owner test accounts.
4. Build/sign release APKs.

The two SQL files in this folder are reference snapshots from the build process. The live Supabase project is currently the source of truth for the later RPC/security hardening migrations.
