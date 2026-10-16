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
- COD checkout
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

Dedicated Supabase ref: `kzvlelcngcxgjsvtvsnj`

Starpoint Garage is not used by these apps.

## CI

`.github/workflows/build-and-smoke.yml` builds, lints, signature-verifies and emulator-smoke-tests both debug APKs.

## Payments

Current policy: COD only. QRIS and bank transfer are disabled.

## Build/UI version and no-reinstall updates

Android apps package their core HTML/JavaScript in a local WebView. Installed copies cannot change their native code or app icons without a signed Android update. The updated APKs include an optional, non-blocking HTTPS stylesheet at `https://raw.githubusercontent.com/rizkyhidayat8999-netizen/Cirengindiapp/main/apps/shared/premium-overrides.css`. Subsequent CSS/theme tweaks to `apps/shared/premium-overrides.css` can take effect when the apps reconnect, without reinstalling. Core checkout/auth changes still require a signed app update (or a supported store update).

The bank checkout migration `supabase/migrations/20261016_two_bank_checkout.sql` and matching `supabase/functions/cirengindi-backend/index.ts` must both be deployed to production before transfer checkout is enabled. Deploy all three active Edge Function routes with the same backend source, preserving current role authorization, then run end-to-end COD and BSI/BRI tests. Do not claim banking features live until DB and function deployments are verified.

Official location: Tanah Grogot, East Kalimantan. The bundled brand logo is used for Member and Owner header and Android launcher icons.
