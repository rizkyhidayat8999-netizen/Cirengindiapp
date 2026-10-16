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
