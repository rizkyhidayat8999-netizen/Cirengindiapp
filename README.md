# appcirengindi

Cireng Indi Android monorepo with two applications and one dedicated Cireng Indi backend.

## Apps

### Member
Path: `apps/member`
Package: `com.cirengindi.member`

Customer functions:
- Register / username login / password recovery
- Home banner, point, member level
- Product catalogue, categories, recommendations
- Product variants and stock
- Cart
- Saved addresses
- Delivery or Pick Up
- COD and bank transfer checkout (BSI / BRI in updated Member app)
- Order history and cancellation rules
- Point, reward redemption and referral
- Profile/logout

### Owner
Path: `apps/owner`
Package: `com.cirengindi.owner`

Owner/staff functions:
- Email/password login restricted to `staff_profiles`
- Daily dashboard
- Order queue and controlled lifecycle transitions
- Product activation
- Variant price/stock management
- Member list + point balance
- Reward stock and redemption fulfillment/cancellation
- Banner/promo activation
- Courier activation and delivery-fee management
- Audit-backed sensitive operations

## Backend

Dedicated Supabase ref: `tbviryuimoxgapubdjio`

Starpoint Garage is not used by these apps.

## CI

`.github/workflows/build-and-smoke.yml` builds, lints, signature-verifies and emulator-smoke-tests both debug APKs.

## Payments

COD and BSI/BRI transfer are enabled in the active Supabase project. The `cirengindi_enable_bsi_bri_checkout` migration was successfully applied. A bank is selected for each transfer order, with an immutable recipient snapshot. The mobile and owner APIs run Edge Function version 7. The public bootstrap and authorization gates passed live CI checks. QRIS is disabled. Full paid-order end-to-end testing requires authorized Member and Owner test sessions.

## Build/UI version and no-reinstall updates

Android apps package their core HTML/JavaScript in a local WebView. Installed copies cannot change their native code or app icons without a signed Android update. The updated APKs include an optional, non-blocking HTTPS stylesheet at `https://raw.githubusercontent.com/rizkyhidayat8999-netizen/Cirengindiapp/main/apps/shared/premium-overrides.css`. Subsequent CSS/theme tweaks to `apps/shared/premium-overrides.css` can take effect when the apps reconnect, without reinstalling. Core checkout/auth changes still require a signed app update (or a supported store update).

The bank migration `supabase/migrations/20261016_two_bank_checkout.sql` is active. The `cirengindi-mobile-api` and `cirengindi-owner-api` Edge Functions were deployed with the checkout and role-validation code; the unchanged `member-auth` route remains deployed. Existing Member apps that do not have the bank selection UI can only display the default BSI transfer destination. Full two-bank bank selection and branding require the updated Member APK, while backend activation does not require reinstalling the existing app.

Official location: Tanah Grogot, East Kalimantan. The bundled brand logo is used for Member and Owner header and Android launcher icons.

## Signed update distribution

- Member release package: `com.cirengindi.member`, version 1.2.0 (3).
- Owner release package: `com.cirengindi.owner`, version 1.1.0 (2).
- Workflow `.github/workflows/release-signed.yml` requires secrets `CI_ANDROID_KEYSTORE_BASE64`, `CI_STORE_PASSWORD`, `CI_KEY_ALIAS`, and `CI_KEY_PASSWORD`.
- Reuse the same securely stored keystore for every release. Existing `.internal` debug APKs use a different Android application ID and cannot update production packages in place.
- Theme changes are fetched from the remote CSS source after initial supported release installation; core code and native icons still require a signed APK/store update.
