# Sekolah Container Template (tanpa bind mount)

Struktur ini menyiapkan image Docker dengan satu container berisi Laravel + dua CodeIgniter sekaligus, lengkap dengan Nginx, PHP-FPM, MariaDB, dan SFTP/SSH. Setiap sekolah dibangun menjadi image berbeda sehingga tidak ada bind mount: update file cukup dilakukan via SFTP lalu `docker commit` jika mau disimpan permanen.

## Cara pakai singkat

1. **Pilih sumber kode**:
  - **Lokal**: letakkan source di `apps/laravel-main`, `apps/ci-a`, `apps/ci-b` sebelum build.
  - **GitHub**: gunakan build arg agar Docker langsung clone repo saat build (contoh di bawah).

2. **Build image khusus sekolah** (lokal atau git):
  ```powershell
  # lokal (pakai isi folder apps/)
  docker build -t school-sekolah01 c:\Users\iyung\Downloads\docker-setup

  # atau langsung tarik dari GitHub
  docker build -t school-sekolah01 `
    --build-arg LARAVEL_REPO=https://github.com/username/laravel-school.git `
    --build-arg LARAVEL_REF=main `
    --build-arg CI_A_REPO=https://github.com/username/ci-a.git `
    --build-arg CI_A_REF=main `
    --build-arg CI_B_REPO=https://github.com/username/ci-b.git `
    --build-arg CI_B_REF=production `
    c:\Users\iyung\Downloads\docker-setup
  ```
  - Untuk repo privat, simpan token di GitHub Secrets/Coolify dan masukkan ke URL (`https://<token>@github.com/...`) atau pakai build secret.

3. **Run container** tanpa bind mount:
   ```powershell
   docker run -d --name sekolah01 -p 2022:22 -p 2080:80 -p 23306:3306 school-sekolah01
   ```
   - Port 2022 → SFTP/SSH (user `devschool`, ganti password atau pakai SSH key sendiri).
   - Port 2080 → Akses HTTP (Laravel default, untuk CI gunakan hostname/path sesuai Nginx).
   - Port 23306 → MySQL/MariaDB (user `school_admin`, password default di `config/mysql/init.sql`).

4. **Edit file via SFTP**: pakai WinSCP/FileZilla (`localhost:2022`, user `devschool`). Semua perubahan tersimpan di dalam layer container.

5. **Backup / snapshot**: jalankan `docker exec` untuk mysqldump, dan gunakan `docker commit sekolah01 sekolah01:snapshot-<tanggal>` untuk simpan state.

6. **Sekolah baru**: ulangi build (ganti repo/build arg atau isi apps) → jalankan container dengan nama & port berbeda.

## Upload ke GitHub

```
cd c:\Users\iyung\Downloads\docker-setup
git init
git add .
git commit -m "Initial school container template"
git remote add origin https://github.com/<username>/<repo>.git
git push -u origin main
```

## Deploy via Coolify

1. Tambah **New Resource → Docker Build** dan konekkan repo GitHub ini.
2. Isi build args (LARAVEL_REPO, CI_A_REPO, dll) di tab *Build Variables* bila ingin auto-clone project.
3. Atur port publik: expose 80 (HTTP), 22 (SFTP), 3306 (MySQL) ke port host yang diinginkan.
4. Deploy → Coolify akan build image per commit dan jalankan container otomatis.
5. Gunakan fitur *Clone Deployment* di Coolify untuk sekolah baru: cukup ubah nama resource + port supaya terpisah.

## Bangun image lewat GitHub Actions

- Workflow `Build School Image` (lihat `.github/workflows/build-image.yml`) bisa dijalankan manual dari tab **Actions → Run workflow**.
- Input yang diminta:
  - `image_tag`: nama tag unik per sekolah (mis. `school-01`).
  - `laravel_repo`, `ci_a_repo`, `ci_b_repo`: otomatis terisi URL repo milik MMT-Indonesia (`absensi-laravel-vue`, `mmt-tagihan-baru-dafi`, `mobile-akademik-holistik`). Ganti kalau perlu repo lain.
  - `laravel_ref`, `ci_a_ref`, `ci_b_ref`: branch atau tag (default `main`).
  - `push_latest`: isi `true` kalau mau tag tambahan `latest`.
- Workflow otomatis:
  1. Checkout repo template ini.
  2. Build image dengan Docker build arg sesuai input.
  3. Push image ke GitHub Container Registry `ghcr.io/<owner>/school:<tag>` (akses lewat `docker pull ghcr.io/<owner>/school:<tag>`).
- Setting awal yang perlu kamu buat di repo GitHub:
  1. Aktifkan GHCR di akun (sekali saja).
  2. Buat **Personal Access Token (classic)** dengan scope `repo` untuk mengakses repo privat.
  3. Simpan token di **Repository Secrets** dengan nama `PRIVATE_GIT_TOKEN` (dan `PRIVATE_GIT_USERNAME` kalau akun git kamu bukan default `x-access-token`). Workflow otomatis menambahkan kredensial itu saat clone, jadi kamu tetap mengisi URL standar `https://github.com/org/repo.git` di input.
- Setelah image ada di GHCR, Coolify bisa langsung deploy via opsi *Docker Image* (cukup isi `ghcr.io/<owner>/school:<tag>` dan expose port). Ulangi workflow untuk sekolah baru agar setiap sekolah punya tag image sendiri tanpa build lokal.

## Catatan penting

- Ganti password default (`devschool`, `ChangeMeNow!`, `ChangeMe123!`) sebelum produksi.
- Untuk Laravel, jalankan `php artisan key:generate`, migrasi, dsb. lewat `docker exec -it sekolah01 bash`.
- Kalau butuh supervisor tambahan (queue worker, scheduler), tambahkan di `config/supervisor/supervisord.conf`.
- Data database tersimpan di volume internal (`/var/lib/mysql`). Gunakan `docker commit` atau backup SQL agar aman sebelum rebuild.
- Bila ingin menggunakan domain nyata, atur reverse proxy/port forwarding di luar container.

## Struktur Folder

```
Dockerfile
README.md
apps/
  laravel-main/
  ci-a/
  ci-b/
config/
  mysql/init.sql
  nginx/conf.d/*.conf
  supervisor/supervisord.conf
scripts/
  entrypoint.sh
```
