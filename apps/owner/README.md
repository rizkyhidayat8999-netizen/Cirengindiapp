# Cireng Indi Owner

Aplikasi Android terpisah untuk owner/staff Cireng Indi.

## Package

- Production: `com.cirengindi.owner`
- Debug/test: `com.cirengindi.owner.internal`
- App label: `Cireng Indi Owner`

## Fungsi

- Login khusus owner/staff menggunakan Supabase Auth email + password
- Verifikasi bahwa user memiliki record di `staff_profiles`
- Dashboard pesanan, omzet selesai, pesanan perlu diproses, stok menipis
- Daftar pesanan dan perubahan status
- Produk dan stok
- Aktif/nonaktif produk
- Daftar member
- Logout

## Keamanan

- Tidak ada service-role key di APK.
- APK hanya membawa publishable key Supabase dan JWT user.
- Akses final tetap harus diamankan oleh RLS/policy Supabase.
- User member biasa ditolak bila tidak memiliki record staff.
- Untuk production, gunakan satu project Supabase khusus Cireng Indi yang dibagi antara aplikasi Member dan Owner.

## Catatan backend

Source test ini masih menunjuk ke project Supabase lama yang dipakai saat development. Setelah project `cirengindi-production` khusus dibuat, ganti `SUPABASE_URL` dan `KEY` di `app/src/main/assets/index.html` pada KEDUA aplikasi sebelum release.

Perubahan status pesanan dari aplikasi Owner menggunakan update tabel `ci_orders`. Sebelum production, validasi trigger/RPC lifecycle di project Supabase khusus Cireng Indi agar stock, notification, dan point completion tetap atomik.


## Dedicated Cireng Indi backend

This Owner source now targets the dedicated Cireng Indi Supabase project:

- Project ref: `kzvlelcngcxgjsvtvsnj`
- API URL: `https://kzvlelcngcxgjsvtvsnj.supabase.co`
- Edge Function: `cirengindi-owner-api`
- Authentication: Supabase Auth email/password, then backend role verification against `staff_profiles`
- No service-role key is present in the APK source.
- Product, order, stock, reward and operational mutations are performed through staff-checked RPCs/Owner API.

No Starpoint Garage backend URL or data is used by this Owner source.
