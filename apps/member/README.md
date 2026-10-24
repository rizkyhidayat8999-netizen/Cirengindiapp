# Cireng Indi Android — Professional UI

Aplikasi Android Cireng Indi dengan UI baru bergaya aplikasi food-ordering premium: bersih, kartu rounded, katalog visual, detail produk, keranjang, checkout modular, pesanan, akun, point/reward, referral, dan alamat.

## Status

- Application ID: `com.cirengindi.member`
- Debug test package: `com.cirengindi.member.internal`
- Version: `1.1.0-test`
- Min Android: API 26
- Target SDK: 36 (Android 16)
- UI: local HTML/CSS/JavaScript di WebView Android dengan Native Bridge
- Session: Android Keystore AES/GCM
- Service-role key: tidak ada di client
- Customer-facing Starpoint/SPG branding: tidak ada
- Payment UI: COD saja

## Backend test

Build test ini masih menunjuk ke backend Supabase Cireng Indi yang sebelumnya dipakai untuk pengembangan. Saat project Supabase khusus Cireng Indi dibuat, cukup mengganti `SB` dan `KEY` pada `app/src/main/assets/index.html`, lalu rebuild.

## Fitur yang terpasang

- Register tanpa OTP
- Login username/password
- Forgot password via email
- Home premium + member point
- Pick Up/Delivery visual flow
- Kategori & katalog
- Detail produk/varian
- Cart + quantity
- Alamat tersimpan
- Checkout COD
- Order history/cancel pending
- Point & reward redeem
- Referral
- Account/logout
- Password recovery deep link

## Build

Gunakan JDK 17, Android SDK 36, dan Gradle 8.13. GitHub Actions workflow tersedia pada `.github/workflows/google-play-member-aab.yml`.


## Two-app architecture

This is the customer-facing Member application.

- Package: `com.cirengindi.member`
- Customer-facing label: `Cireng Indi`
- Shares one dedicated Cireng Indi Supabase project with the Owner app.
- Does not share a project with Starpoint Garage in the target production architecture.
- Owner/admin controls must never be exposed in this APK.


## Dedicated Cireng Indi backend

This source now targets the dedicated Cireng Indi Supabase project:

- Project ref: `kzvlelcngcxgjsvtvsnj`
- API URL: `https://kzvlelcngcxgjsvtvsnj.supabase.co`
- Client key: modern Supabase publishable key
- Edge Functions: `member-auth`, `cirengindi-mobile-api`
- Payments: COD only
- Fulfillment: Delivery and Pick Up
- Product assets: bundled locally in the APK as the primary image source

No Starpoint Garage backend URL or branding is used by this Member source.
