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

## Final v2.0.0 — automatic UI updates

Both **production signed** Android packages include a native remote-HTML bootstrap:
- Member: `com.cirengindi.member`, version `2.0.0`, versionCode `4`
- Owner: `com.cirengindi.owner`, version `2.0.0`, versionCode `3`

On cold start, `RemoteHtmlUpdater` fetches the appropriate application HTML from this trusted repository over HTTPS:
- `apps/member/app/src/main/assets/index.html`
- `apps/owner/app/src/main/assets/index.html`

The HTML is validated, cached privately for offline use and loaded under the existing local WebView origin so bundled product/logo assets still resolve. It falls back to the cached or bundled copy on connection failure. Future HTML/CSS/JS changes pushed to this repository appear automatically at a subsequent launch **without installing another APK**. This requires internet connectivity for fetching updates. The GitHub raw CDN may cache changes briefly.

**Not supported:** Automatic updates of the Android native binary, permissions, and home-screen launcher icon. Those still require a properly signed APK update delivered through Android/Play Store. OTA HTML changes are trusted code controlled by repository maintainers; protect GitHub access and review changes before merging. Never load arbitrary third-party HTML.

The official logo PNG is bundled identically in both APKs and their native Android launcher icons, and the outlet is Tanah Grogot, East Kalimantan.

## Payments

COD and BSI/BRI are enabled in Supabase project `tbviryuimoxgapubdjio`. Each transfer checkout selects a recipient and keeps an immutable bank snapshot. QRIS is disabled. Owner reviews uploaded transfer proofs. End-to-end paid transaction verification with real test accounts is still required.

## Signing and future native releases

The first production v2.0.0 Member and Owner APKs were both compiled and signed in one GitHub Actions run:
[Production signing build](https://github.com/rizkyhidayat8999-netizen/Cirengindiapp/actions/runs/38840557809).

The private signing key was generated once and **never committed to the repository**. Its GitHub Actions recovery artifact was encrypted to a public-only recovery certificate and can be decrypted with the separately held private recovery key. The recovered release keystore and credentials must be stored offline by the owner and imported into GitHub Actions encrypted secrets for subsequent releases:

- `CI_ANDROID_KEYSTORE_BASE64`: Base64 of the original JKS keystore bytes
- `CI_STORE_PASSWORD`: password from private recovery credentials
- `CI_KEY_ALIAS`: alias from private recovery credentials
- `CI_KEY_PASSWORD`: password from private recovery credentials

`.github/workflows/release-signed.yml` builds future signed Android releases with that same key. **Never regenerate the key**: a different signing certificate cannot update these packages without uninstalling the old app. First-time installation of these production IDs is separate from previously distributed `.internal` debug packages. Existing users of production IDs signed with any different earlier key also cannot install these as an in-place update.

Release signing certificate SHA-256:
`D4:57:44:40:D6:92:27:2E:B9:64:E9:BC:C1:1A:0B:57:DF:D6:57:30:6C:8A:31:C9:DB:A6:E6:89:D7:AD:ED:A1`.

The one-time signing bootstrap workflow was removed after completion to prevent accidentally creating a second incompatible signing key.
