# Rekap Final Cireng Indi — UI, Data, Aplikasi & Backend

## Arsitektur

Cireng Indi sekarang disiapkan sebagai satu bisnis dengan satu backend Supabase khusus dan dua aplikasi Android:

- **Cireng Indi Member** — package `com.cirengindi.member`.
- **Cireng Indi Owner** — package `com.cirengindi.owner`.
- Keduanya menggunakan project Supabase khusus Cireng Indi `kzvlelcngcxgjsvtvsnj`.
- Starpoint Garage tidak digunakan oleh source baru ini.
- Client hanya membawa Supabase **publishable key**, tidak membawa service-role key.

## UI Cireng Indi Member

Desain mengikuti pola UX aplikasi food-ordering modern seperti referensi Fore yang diberikan, tetapi menggunakan warna, logo, aset, produk, dan copy Cireng Indi sendiri. Ikon memakai SVG profesional, bukan emoji dekoratif.

Screen/flow Member:

1. Login / Daftar / Lupa Password.
2. Home: banner promo, logo Cireng Indi, salam member, point, level, status.
3. Pilihan produk Siap Makan / Frozen.
4. Feature cards: Reward, Paket Reseller, Paket Cafe, Referral.
5. Store: Pick Up / Delivery, lokasi outlet, alamat delivery, category chips, promo, rekomendasi dan katalog.
6. Detail produk: foto, deskripsi, pilihan varian, harga, jumlah, catatan, estimasi point.
7. Bottom sheet setelah tambah ke keranjang.
8. Keranjang: quantity dan subtotal.
9. Alamat tersimpan + default address.
10. Checkout Delivery atau Pick Up.
11. Pembayaran COD saja.
12. Riwayat/status pesanan dan pembatalan saat masih diizinkan.
13. Point & Reward + redeem.
14. Profil, referral, alamat, logout.

## UI Cireng Indi Owner

Screen/flow Owner:

1. Login email/password khusus Owner/Staff.
2. Dashboard: pesanan hari ini, omzet selesai, antrean proses, stok menipis, produk aktif, member aktif, reward pending.
3. Pesanan: filter status dan lifecycle `pending → processing → shipped → completed`; cancel hanya pada tahap yang diizinkan.
4. Produk & Stok: aktif/nonaktif produk, lihat/edit varian, harga dan stok.
5. Member: identitas akun, level dan saldo point.
6. Reward: stok reward dan proses penukaran.
7. Promo/Banner: aktif/nonaktif banner.
8. Kurir: aktif/nonaktif dan ongkir.
9. Lainnya: identitas staff, keamanan, versi aplikasi, logout.

## Data Produksi yang Sudah Masuk ke Supabase Khusus Cireng Indi

- 4 kategori aktif.
- 31 produk aktif.
- 42 varian aktif.
- 4 banner aktif.
- 12 reward aktif.
- 3 kurir aktif.
- Stock awal varian hasil seed aplikasi: 20 per varian.
- Pembayaran: **COD aktif; QRIS dan transfer nonaktif**.
- Fulfillment: **Delivery + Pick Up**.
- Level member: Classic / Silver / Gold / Platinum.
- Aturan point saat order completed: 1 point per Rp10.000 subtotal produk.

### Produk & Varian

| Produk | Kategori | Varian / Harga |
|---|---|---|
| Cireng | Cireng & Jajanan | 520 gr — Rp30.000; 1 kg — Rp55.000 |
| Cireng Isi | Cireng & Jajanan | Original isi 6 — Rp25.000; Ayam Pedas isi 6 — Rp25.000 |
| Cilok | Cireng & Jajanan | 520 gr — Rp30.000; 1 kg — Rp55.000 |
| Sempol Ayam | Cireng & Jajanan | Isi 30 — Rp40.000; Isi 45 — Rp60.000 |
| Tahu Bakso | Cireng & Jajanan | Isi 10 — Rp35.000 |
| Pempek Ikan Tenggiri | Cireng & Jajanan | Per box — Rp25.000; 500 gr — Rp55.000; 1 kg — Rp110.000 |
| Chicken Katsu | Frozen Food | 250 gr — Rp28.000; 500 gr — Rp55.000; 1 kg — Rp110.000 |
| Nugget Ayam | Frozen Food | 250 gr — Rp30.000; 500 gr — Rp60.000; 1 kg — Rp120.000 |
| Bola Ayam Keju | Frozen Food | Box isi 10 — Rp40.000 |
| Bitterballen | Frozen Food | Box isi 10 — Rp40.000 |
| Bakso Ayam | Frozen Food | Isi 25 — Rp28.000; Isi 50 — Rp55.000 |
| Ebi Furai | Frozen Food | 1 box — Rp40.000 |
| Baceman Frozen | Frozen Food | 1 box — Rp35.000 |
| Ayam Ungkep | Frozen Food | Isi 5 — Rp60.000 |
| Dimsum Crispy | Frozen Food | 1 box — Rp40.000 |
| Rollade Ayam | Frozen Food | 1 box — Rp35.000 |
| Kebab Pisang | Frozen Food | 1 box — Rp35.000 |
| Kebab Daging | Frozen Food | 1 box — Rp45.000 |
| Corndog | Frozen Food | 1 box — Rp30.000 |
| Churros | Frozen Food | 1 box — Rp30.000 |
| Kentang Goreng Frozen | Frozen Food | 1 box — Rp25.000 |
| Frozen Mix Platter | Frozen Food | 1 pack — Rp75.000 |
| Jamu Manjakani | Jamu & Minuman | Botol — Rp28.000 |
| Jamu Komplit | Jamu & Minuman | Botol — Rp28.000 |
| Jamu Kunyit Asam | Jamu & Minuman | Botol — Rp28.000 |
| Jahe Latte | Jamu & Minuman | Pack — Rp30.000 |
| Jahe Original | Jamu & Minuman | Pack — Rp28.000 |
| Sari Kacang Hijau | Jamu & Minuman | Botol — Rp28.000 |
| Puding Mix | Menu Lainnya | 1 pack — Rp20.000 |
| Salad Jelly | Menu Lainnya | 1 cup — Rp15.000 |
| Rengginang | Menu Lainnya | 1 pack — Rp35.000 |

### Reward

| Reward | Varian | Point |
|---|---|---:|
| Cireng | 520 gr | 60 |
| Jamu | Varian Rp28.000 | 60 |
| Chicken Katsu | 250 gr | 60 |
| Nugget Ayam | 250 gr | 60 |
| Cilok | 520 gr | 60 |
| Bakso Ayam | Isi 25 | 60 |
| Dimsum Crispy | 1 box | 80 |
| Rollade Ayam | 1 box | 70 |
| Baceman Frozen | 1 box | 70 |
| Churros | 1 box | 60 |
| Kentang Goreng Frozen | 1 box | 50 |
| Ebi Furai | 1 box | 80 |

## Promo / Paket

- Bonus Puding: minimum Rp150.000 → gratis 2; minimum Rp250.000 → gratis 5.
- Paket Cafe: 50 pax Rp500.000; 100 pax Rp950.000.
- Paket Reseller: 5 kg Rp225.000; 10 kg Rp425.000.

## Backend Supabase Khusus Cireng Indi

Project URL: `https://kzvlelcngcxgjsvtvsnj.supabase.co`

Data layer utama:

- `member_profiles`, `staff_profiles`.
- `ci_categories`, `ci_products`, `ci_product_variants`, `ci_banners`.
- `ci_couriers` + private `ci_courier_contacts`.
- `ci_addresses`, `ci_carts`, `ci_cart_items`.
- `ci_orders`, `ci_order_items`, `ci_payments`, `ci_refunds`.
- `ci_point_ledger`, `ci_rewards`, `ci_reward_redemptions`.
- `ci_notifications`, `ci_device_tokens`, `ci_app_settings`, audit/rate-limit tables.

Edge Functions aktif:

- `member-auth` v1 — register/login/forgot password.
- `cirengindi-mobile-api` v2 — API Member.
- `cirengindi-owner-api` v3 — API Owner/Staff.

Storage:

- Bucket `cirengindi-products` sudah dibuat.
- Public read, staff-only write.
- APK Member saat ini memakai aset produk lokal sebagai prioritas sehingga gambar tetap tampil walaupun objek Storage belum di-upload.

## Keamanan

- Row Level Security aktif pada tabel aplikasi.
- Member hanya membaca data miliknya sendiri.
- Owner/Staff divalidasi dengan `staff_profiles` dan pemeriksaan server-side.
- Mutasi stok/order/reward Owner dilakukan melalui RPC dengan pemeriksaan staff.
- Anonymous execute telah dicabut dari seluruh RPC Cireng Indi.
- Kontak kurir dipisah dari tabel kurir publik.
- Service-role hanya dipakai di server Edge Function untuk kebutuhan Auth; tidak ada di APK.


## Validasi Backend Terakhir

- 21 tabel aplikasi berprefix `ci_`; seluruh 21 sudah RLS-enabled.
- 31 produk, 42 varian, 4 kategori, 4 banner, 12 reward dan 3 kurir terverifikasi di database.
- `anon` tidak memiliki execute privilege pada RPC SECURITY DEFINER Cireng Indi (`0` RPC Cireng yang executable oleh anon).
- Edge Functions aktif: `member-auth` v1, `cirengindi-mobile-api` v2, `cirengindi-owner-api` v3.
- Security Advisor masih memberi warning generik untuk SECURITY DEFINER yang memang boleh dipanggil user login; masing-masing fungsi tetap memvalidasi `auth.uid()` atau role staff di server. Tidak ada anonymous Cireng RPC yang executable.
- Performance Advisor hanya melaporkan index belum terpakai; wajar karena database baru belum memiliki traffic/order.

## Status akun saat ini

- Auth user: 0.
- Member: 0.
- Staff/Owner: 0.
- Order: 0.

Artinya backend sudah siap menerima pendaftaran Member, tetapi **akun Owner belum dibuat** karena belum ada email Owner yang valid untuk Supabase Auth. Email tidak diinventarisir/diarang oleh sistem.

## Yang masih menjadi gate sebelum release production

1. Buat Auth user Owner dengan email valid lalu hubungkan ke `staff_profiles` sebagai `owner`.
2. Tambahkan `https://cirengindi.com/reset-password` ke Supabase Auth Redirect URLs dan pastikan route web tersebut aktif.
3. Hubungkan kembali GitHub yang mempunyai repository **appcirengindi**. Koneksi GitHub pada sesi ini saat ini mengembalikan 0 repository, jadi source belum dapat di-push secara jujur.
4. Jalankan GitHub Actions build + lint + emulator smoke test untuk Member dan Owner.
5. Setelah lolos, sign APK/AAB release menggunakan signing key milik bisnis.

## Catatan migrasi data

Dump database lama sebelumnya berisi 31 produk dan 38 varian. APK terakhir ternyata membawa seed aplikasi yang lebih baru: **31 produk dan 42 varian**. Backend khusus Cireng Indi ini memakai seed aplikasi terbaru (31/42) supaya data backend konsisten dengan aplikasi yang akan dirilis.
