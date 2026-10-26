# Rancangan: engine tokoh yang membaca bab demi bab

Status: draf untuk disetujui. Ditulis 26 Oktober 2026, berdasarkan diskusi di branch `Feature-tune`.

## Maksud dan alasannya

Engine tokoh sekarang (lihat `WALKTHROUGH.md`) bekerja dalam dua fase untuk **seluruh buku sekaligus**: NaturalLanguage dan aturan menemukan dan menautkan semua mention, lalu Foundation Models dipanggil sebagai **wasit** untuk kasus yang aturan ragukan. Hasilnya kurang baik karena:

1. **Model tidak pernah membaca cerita.** Ia hanya memilih di antara kandidat yang disiapkan aturan, melihat 3–4 kalimat per panggilan, tanpa ingatan tentang tokoh, dan kandidatnya hanya berupa nama. Ia tidak bisa menambah nama yang terlewat (misalnya "Margaret" di s136 Little Women) dan tidak bisa membandingkan sifat ("snow maiden, yellow hair" seharusnya Amy, tapi tertaut ke Beth).
2. **Pengetahuan tidak menumpuk.** Keputusan di Bab 1 tidak membantu Bab 5.
3. **Semua dihitung ulang** setiap kali aplikasi dibuka, termasuk sekitar 4 menit fase model.

Rancangan ini mengubah engine menjadi **pembaca bab demi bab**: setiap bab dianalisis dengan membawa **ingatan tokoh** dari bab-bab sebelumnya, model membaca bab itu (bukan hanya menjadi wasit), dan hasil tiap bab **disimpan di perangkat** supaya tidak dihitung ulang.

## Sasaran

- Bab dianalisis **berurutan**, mulai dari bab cerita pertama (`BookContent.storyChapter.lowerBound`).
- Setiap bab memakai dan memperbarui **ingatan tokoh**: nama, alias, sifat, dan kalimat perkenalan.
- Foundation Models **membaca bab per potongan** dengan ingatan tokoh sebagai konteks, dan boleh:
  - memutuskan mention dari aturan milik tokoh mana;
  - menunjuk nama tokoh yang terlewat aturan;
  - menyatakan bahwa dua nama adalah orang yang sama;
  - mencatat sifat tokoh yang baru disebut.
- Setiap jawaban model **wajib punya bukti** di potongan yang dikirim, dan diperiksa sebelum dipakai (pengembangan `EvidenceGuard`).
- Hasil tiap bab **disimpan di perangkat** dan dipakai lagi saat buku dibuka ulang. Analisis yang terputus (aplikasi ditutup) **dilanjutkan dari bab terakhir yang belum selesai**.
- Hasil tersimpan diberi **versi engine**. Kalau versi berubah (karena knob atau aturan diubah), hasil lama dianggap basi dan dihitung ulang, supaya efek tuning terlihat.
- Simbol dan garis bawah untuk sebuah bab muncul setelah bab itu selesai, **tanpa perubahan tampilan apa pun**.

## Bukan sasaran

- **Perubahan tampilan untuk pembaca:** tidak ada pil progres, tidak ada indikator baru. View debug lokal (yang sudah ada di branch ini dan tidak di-push) boleh disesuaikan.
- **Kata ganti** ("she", "he", "it"): di luar cakupan rilis ini menurut PRD 2.1. Engine tidak menautkan kata ganti.
- **Tempat dan event:** tetap tokoh saja (P0).
- **Pemrosesan di cloud,** termasuk Private Cloud Compute.
- **Bahasa selain Inggris.**
- **Mengganti NaturalLanguage dengan model lain** (misalnya BookNLP). NaturalLanguage dan aturan tetap jadi penyaring cepat dan sumber kandidat.

## Yang harus dihindari (gagal walaupun "jalan")

- **Spoiler.** Ingatan tokoh, kartu tokoh, dan keputusan model tidak boleh memakai apa pun yang terletak sesudah kalimat yang sedang diputuskan. Penggabungan tetap dicatat dengan kalimat tempat buktinya muncul (`mergedAtSentence`). Bug `merge` yang sekarang (tujuan dicari lewat `finalKey`, sehingga s115 "a little girl" menjadi Jenny Snow dari s1504) harus diperbaiki sebagai bagian dari ini.
- **Simbol yang berganti di depan pembaca.** Setelah sebuah bab tampil dengan simbolnya, bab berikutnya tidak boleh mengubah simbol tokoh yang sudah tampil. Simbol dibagikan sekali, saat tokoh pertama kali lolos syarat tampil, dan tidak dibagikan ulang. Urutan seri (beberapa tokoh muncul di kalimat yang sama) harus pasti, misalnya menurut posisi di kalimat, bukan acak. Satu-satunya pengecualian adalah penggabungan dua tokoh bersimbol (lihat "Dua tokoh bersimbol ternyata orang yang sama").
- **Hasil tersimpan yang mengabaikan perubahan knob.** Lihat versi engine di atas.
- **Aplikasi melambat atau panas.** Satu panggilan model sekali jalan, prioritas `.utility`, berhenti sementara saat `thermalState` serius atau Low Power Mode aktif (PRD 2.1 §5.3).
- **Buku gagal dibuka karena analisis gagal.** Kegagalan analisis sebuah bab tidak boleh memengaruhi pembacaan; bab itu ditandai gagal dan analisis lanjut ke bab berikutnya dengan ingatan dari bab terakhir yang berhasil.

## Batasan

- **Platform:** iOS/iPadOS 26, Swift 6, xcodegen (`xcodegen generate` setelah menambah file).
- **Foundation Models:**
  - Ukuran konteks dibaca saat jalan (`SystemLanguageModel.default.contextSize`; sekitar 4.000 token), dan prompt diukur dengan `tokenCount(for:)` bila tersedia. Kalau tidak tersedia, perkiraan konservatif 1 token per 3 karakter (PRD 2.1 §5.3 B).
  - Satu panggilan sekali jalan, sesi baru per panggilan, `prewarm()` saat analisis mulai.
  - Jawaban berbentuk terstruktur (`@Generable`).
  - Kalau model tidak tersedia (perangkat tidak mendukung, Apple Intelligence mati), setiap bab tetap dianalisis dengan NaturalLanguage dan aturan saja.
- **Konvensi layer aplikasi** (PRD 1.0 §3.4–3.5), seperti engine sekarang:
  - `Models/` hanya data; `Rules/` logika murni sebagai `enum` dengan fungsi statis; `Svc/` layanan; `Repo/` penyimpanan dan cache; `Ctrl/` dan `VM/` seperti sekarang.
  - File engine di subfolder `AI/`.
  - Knob di bagian atas file langkahnya (`enum …Knobs`).
  - Tanpa komentar di kode.
- **Ketergantungan:** rentang bab cerita datang dari `BookContent.storyChapter`, yang diisi parser menurut rancangan awal cerita (landmark `bodymatter`, pola judul bab, aturan daftar isi, lalu bab pertama). Rancangan itu sudah disetujui dan dikerjakan terpisah; engine ini hanya membaca hasilnya. Sebelum rancangan itu masuk, engine memakai `StoryStart` versi engine yang ada sekarang.
- **Perbaikan aturan yang sudah diuji** ikut dipakai sebagai bagian aturan per bab. Kodenya sudah diberikan di percakapan sebagai potongan untuk ditempel, dan belum ada di branch. Aturannya persis:
  - **A.** Kata yang tidak diawali huruf kapital tidak pernah dianggap nama, walau NLTagger melabelinya `PersonalName` (mis. "brown" di s137).
  - **B.** Sebuah kata dianggap nama di mana pun ia muncul berhuruf kapital, termasuk di awal kalimat, kalau: NLTagger pernah melabelinya nama minimal sekali, ia muncul berhuruf kapital di tengah kalimat minimal `minCapitalizedMidSentence` (2) kali, dan kemunculan huruf kecilnya paling banyak `maxLowercaseRatio` (0,2) kali jumlah kemunculan kapital di tengah kalimat. Knob `propagateKnownNames` menyalakan aturan ini.
  - **C.** `MentionLinkerKnobs.appositionConnectors` ditambah pola `^\s*(was|is)\s*$` dan `^,?\s*(called|named|known as)\s*$`.
  - Hasil uji di Little Women (fase 1 lama): "Margaret" di s136 dikenali; mention Meg naik dari 80 ke 681; "brown" bukan nama lagi; undecided turun dari 405 ke 399; dari 16 tautan baru C, sekitar 14 benar.

## Cara kerja yang sudah diputuskan

### Unit kerja: satu bab

Engine memproses bab-bab cerita **satu per satu, berurutan**. Bab yang sedang dibaca **tidak** didahulukan: kalau pembaca melompat jauh ke depan, tanda di bab itu muncul setelah bab-bab sebelumnya selesai. Alasannya, tanda yang muncul terlambat tapi benar lebih baik daripada tanda yang muncul cepat lalu berubah (keputusan "ketepatan dulu").

**Tanda sebuah bab baru tampil setelah model selesai membaca bab itu** (keputusan pemilik produk, 26 Oktober 2026). Tanda dari aturan saja tidak ditampilkan lebih dulu. Ini sengaja menyimpang dari target PRD 2.1 "tanda pertama ≤ 3 detik": tanda Bab 1 butuh beberapa panggilan model, dan pembaca yang membuka buku di tengah menunggu semua bab sebelumnya selesai. Hasil tersimpan membuat penantian ini hanya terjadi sekali per buku. Pengecualian: kalau model tidak tersedia, bab dianalisis dengan aturan saja dan tandanya tampil setelah itu.

### Dua tokoh bersimbol ternyata orang yang sama

Kalau model (atau aturan) menyimpulkan dua tokoh yang sama-sama sudah bersimbol adalah satu orang, misalnya "Margaret" dan "Meg" (keputusan pemilik produk, 26 Oktober 2026):
- Mulai dari kalimat bukti penggabungan, **keduanya memakai simbol tokoh yang lebih dulu dikenal**.
- Halaman sebelum kalimat itu tetap memakai simbol lama masing-masing, sesuai aturan "sejauh pembaca tahu di kalimat itu".
- Simbol tokoh yang digabung tidak dipakai lagi untuk tokoh lain.

### Pra-pembacaan seluruh buku (hanya NaturalLanguage)

Sebelum bab pertama dianalisis, semua kalimat cerita dilabeli NLTagger sekali (target PRD: seluruh buku ≤ 60 detik; di Mac sekitar 1–2 detik). Dari situ engine mengumpulkan **kosakata nama**: kata mana yang dihitung nama (aturan B) dan berapa kali tiap nama muncul di seluruh cerita. Ini bukan spoiler, karena tidak ada yang ditampilkan dari situ. Ia hanya menentukan apakah sebuah kata adalah nama, dan apakah sebuah nama cukup sering muncul untuk jadi tokoh.

Akibatnya:
- "Margaret" di s136 dikenali di Bab 1, walau NLTagger baru melabelinya nama di s1871.
- Nama yang lolos `minNameCount` di seluruh buku langsung jadi tokoh **sejak kemunculan pertamanya**. Tidak perlu menambah tanda ke bab yang sudah selesai.
- Tokoh bernama lolos syarat tampil (`minimumMentions`) berdasarkan jumlah kemunculan namanya di seluruh cerita, jadi simbol Jo sudah ada di Bab 1.
- Tokoh yang hanya dikenal lewat deskripsi tetap tumbuh bertahap. Ia mendapat simbol mulai dari bab tempat ia lolos syarat, dan bab yang sudah selesai **tidak** ditambah tanda.

### Satu bab, langkah demi langkah

1. **Ambil kalimat bab** (nomor kalimat global tetap, s0, s1, …).
2. **Tag kata** dengan NLTagger (`WordTagSvc`, tidak berubah).
3. **Cari mention** dengan aturan (`MentionFinder`, termasuk perbaikan A dan B).
4. **Perbarui calon tokoh:** nama yang sudah dikenal di ingatan langsung dipakai. Nama baru dihitung kemunculannya lintas bab, dan jadi tokoh setelah mencapai batas (`minNameCount`), mis. sekali di Bab 1 dan sekali di Bab 5 berarti jadi tokoh di Bab 5. Alias "X, or Y" tetap ditangkap aturan.
5. **Tautkan dengan aturan** (`MentionLinker`, termasuk perbaikan C), memakai ingatan tokoh sebagai daftar tokoh yang sudah dikenal.
6. **Model membaca bab per potongan** (ukuran potongan dihitung dari anggaran token):
   - **Masuk:** kalimat-kalimat potongan (bernomor); daftar mention dari aturan di potongan itu; dan **kartu tokoh** dari ingatan: nama, alias, sampai 3 sifat utama, dan kalimat perkenalan (dipotong sekitar 40 kata). Kartu hanya untuk tokoh yang relevan dengan potongan itu, sebanyak muat di anggaran.
   - **Keluar,** semuanya dengan nomor kalimat bukti:
     - mention mana milik tokoh mana, tokoh baru, atau bukan tokoh;
     - nama tokoh yang terlewat aturan, ditulis persis seperti di teks;
     - dua nama yang orang yang sama;
     - sifat tokoh yang disebut di potongan, ditulis persis seperti di teks.
7. **Periksa bukti** sebelum dipakai: teks yang disebut model harus ada persis di potongan, kalimat bukti harus ada di potongan dan tidak sesudah hal yang diputuskan, dan gabungan nama butuh kalimat yang mendukung. Jawaban yang gagal diperiksa dibuang diam-diam.
8. **Perbarui ingatan tokoh** (nama, alias, sifat, gabungan, semuanya dengan kalimatnya), lalu **simpan hasil bab**.
9. **Gabungkan** hasil semua bab yang sudah selesai menjadi satu `BookAnalysis` (`AnalysisMapper`, bentuk keluaran tidak berubah), lalu beri tahu layar untuk memuat ulang tanda.

### Kalau model gagal

- **Satu potongan gagal** (model menolak teks karena aturan keamanan, konteks penuh, atau error lain): potongan itu memakai hasil aturan saja, dan bab tetap dihitung selesai. Ingatan tokoh tetap diperbarui dari bagian yang berhasil.
- **Seluruh bab gagal** (mis. error saat menyimpan, atau bab rusak): bab ditandai gagal, analisis lanjut ke bab berikutnya dengan ingatan dari bab terakhir yang berhasil, dan bab itu tanpa tanda.
- **Tidak dicoba ulang otomatis.** Potongan dan bab gagal hanya dihitung ulang saat versi engine berubah. Jumlah potongan yang gagal dicatat di hasil bab, supaya terlihat di view debug.
- **Kalau `exceededContextWindowSize`:** potongan dibelah dua dan dicoba sekali lagi (PRD 2.1 §5.3 B).

### Kapan analisis berjalan

- Hanya saat aplikasi di depan layar. Foundation Models tidak bisa dipakai di latar belakang.
- Satu buku sekali jalan: buku yang paling akhir dibuka. Analisis lanjut walaupun pembaca menutup buku dan kembali ke Library, selama aplikasi masih di depan. Kalau buku lain dibuka, analisis buku sebelumnya berhenti di bab terakhir yang tersimpan, dan dilanjutkan saat buku itu dibuka lagi.

### Penyimpanan

- Per buku, satu file per bab di folder buku di perangkat (di sebelah EPUB yang diimpor, `Application Support/Books/<id>/`). Little Women bawaan juga punya folder sendiri.
- Isi per bab: mention bab itu beserta keputusannya, ingatan tokoh **di akhir bab**, dan versi engine.
- Saat buku dibuka: muat semua bab tersimpan yang versinya cocok, berurutan, berhenti di bab pertama yang belum ada atau basi. Dari situ analisis dilanjutkan.
- Versi engine adalah satu angka di knob. Menaikkannya membuat semua hasil tersimpan basi.

### Perubahan per layer

| Layer | Perubahan |
|---|---|
| `Analysis/AI/Models` | Baru: ingatan tokoh, hasil bab, permintaan dan jawaban "baca potongan". Tipe engine yang disimpan dibuat `Codable`. |
| `Analysis/AI/Rules` | Baru: pemotong bab sesuai anggaran token; pembuat kartu tokoh. Diubah: `CastBuilder` mulai dari ingatan, bukan kosong; `MentionLinker` menerima ingatan; `EvidenceGuard` untuk jenis jawaban baru; `ResolvedAnalysis.merge` diperbaiki (spoiler). Pemecah seri yang pasti untuk urutan simbol. |
| `Analysis/AI/Svc` | `AnalysisScheduleSvc` diganti layanan analisis per bab. `LLMSvc`/`LLMSvcFoundation` mendapat kemampuan "baca potongan" dan menggantikan dua pertanyaan sempit sekarang. `TieBreakSvc` dihapus atau diserap. |
| `Analysis/Repo` | `AnalysisRepo` mengatur urutan bab, memuat dan menyimpan hasil, dan menerbitkan `BookAnalysis` terbaru setiap bab selesai. Baru: penyimpanan hasil bab di disk. |
| `Analysis/Ctrl` | `RefCtrl`: `prepare()` dan `refine()` menjadi satu pemicu analisis; `marks`, `entity`, `passage` tidak berubah. |
| `Reader/VM` | `ReferenceVM` memuat ulang tanda setiap kali satu bab selesai. |
| `Reader/Views` | Tidak berubah (selain view debug lokal). |

## Yang diserahkan ke builder

- Ukuran potongan, isi persis prompt dan instruksi model, dan skema jawaban `@Generable`.
- Format file penyimpanan (JSON atau lainnya) dan nama file.
- Cara `AnalysisRepo` memberi tahu layar bahwa bab selesai (misalnya `AsyncStream`), selama `RefCtrl`/`ReferenceVM` tetap sederhana.
- Cara memilih kartu tokoh yang relevan untuk sebuah potongan.
- Knob baru apa saja yang perlu (selain versi engine), dan nilai awalnya.
- Bagaimana tokoh kecil yang hanya dikenal lewat deskripsi dibuang secara bertahap (sekarang dibuang sekali di akhir seluruh buku).
- Penyesuaian view debug lokal.

## Keputusan yang kubuat sendiri (perlu dicek)

- **Pra-pembacaan seluruh buku dengan NLTagger** untuk kosakata nama dan jumlah kemunculan nama. Ini membuat tokoh bernama dapat simbol sejak kemunculan pertama, tanpa menambah tanda ke bab yang sudah selesai.
- **Tokoh deskripsi tidak menambah tanda ke bab yang sudah selesai.** File bab ditulis sekali.
- **Simbol tidak pernah dibagikan ulang** setelah tampil.
- **Potongan yang gagal memakai hasil aturan,** dan babnya tetap selesai. Tidak ada percobaan ulang otomatis kecuali versi engine berubah.
- **Analisis berjalan selama aplikasi di depan,** satu buku sekali jalan.
- **Kata ganti tetap di luar cakupan,** mengikuti PRD.
- **Kalau model tidak tersedia,** bab dianalisis dengan aturan saja dan tidak dianalisis ulang otomatis saat model tersedia kemudian, kecuali versi engine berubah.
