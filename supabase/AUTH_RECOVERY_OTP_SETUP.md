# OTP pemulihan password Member Cireng Indi

Backend `member-auth` dan halaman Member sudah menerima OTP email **6 digit**
melalui Supabase GoTrue `verifyOtp({email,token,type:'recovery'})`.
Akun baru Member **tidak** memerlukan verifikasi email. Owner tidak diubah.

## Langkah wajib: aktifkan kode pada email

Saat ini email **Reset Password** Supabase mungkin masih menggunakan template
berisi tautan (`{{ .ConfirmationURL }}`). Aplikasi **tidak boleh** mengklaim email
sudah mengirim OTP sebelum template email ini diaktifkan.

1. Buka [Supabase — Email Templates](https://supabase.com/dashboard/project/tbviryuimoxgapubdjio/auth/templates).
2. Pilih **Reset Password** (Recovery), **bukan** Confirm Signup dan bukan Magic Link.
3. Atur subject: `Kode OTP Reset Password Cireng Indi`.
4. Tempel isi file [recovery-otp.html](./auth-templates/recovery-otp.html) pada
   editor **Body/HTML**. Simpan pengaturan.
5. Pastikan layanan email Supabase (SMTP atau pengirim yang sudah dikonfigurasi)
   dapat mengirim ke alamat pelanggan.
6. Lakukan pengujian dengan **email akun Member milik penguji**, bukan email milik
   pelanggan lain: Lupa Password → Kirim Email Pemulihan → cek kode 6 digit →
   masukkan kode dan email → password baru → login lagi.
7. Periksa kode salah, kode kedaluwarsa, dan pengiriman berulang. Jangan
   mencatat kode/token pemulihan dalam logs.

Template asli dan pengaturan Owner harus tetap dipertahankan.

Jika pengaturan email belum bisa diubah, aplikasi masih menerima **tautan
pemulihan lama** melalui bagian "Gunakan tautan dari email sebagai alternatif".
Tautan tidak perlu dibuka di localhost. Pengguna hanya menyalin tautan tersebut.

Penjelasan Supabase: https://supabase.com/docs/guides/auth/auth-email-templates
(`{{ .Token }}` adalah OTP 6 digit; `{{ .ConfirmationURL }}` adalah tautan).

Jangan menempatkan Management API PAT, SMTP password, service-role key, atau kode
OTP pengguna di repository atau dalam isi template.
