# Walkthrough: alur data engine tokoh

Dokumen ini mengikuti **data** dari saat pembaca membuka buku sampai simbol dan garis bawah muncul di halaman. Setiap pemberhentian berisi empat hal:

- **Masuk**: data yang diterima, dengan contoh nyata
- **Fungsi**: file dan fungsi yang mengolahnya, termasuk fungsi `private`
- **Keluar**: data yang dihasilkan, dengan contoh nyata
- **Knob**: nilai yang bisa diubah untuk menala langkah itu

Untuk siapa: engineer yang akan menala engine. Tidak perlu bisa menulis Swift. Cukup tahu bahwa `struct`/`enum` adalah tipe data, `func` adalah fungsi, `async` berarti fungsinya bisa menunggu, dan `private` berarti fungsi itu hanya dipakai di dalam file-nya.

## Contoh yang dipakai di seluruh dokumen

**Little Women, Bab 1, kalimat s91 sampai s175**, kira-kira halaman 6 sampai 8 di iPad Pro 13 inci dengan ukuran huruf bawaan. Di bagian ini keempat saudari diperkenalkan:

> **s141**: Elizabeth, or Beth, as everyone called her, was a rosy, smooth-haired, bright-eyed girl of thirteen, with a shy manner, a timid voice, and a peaceful expression which was seldom disturbed.
>
> **s143**: Amy, though the youngest, was a most important person, in her own opinion at least.
>
> **s144**: A regular snow maiden, with blue eyes, and yellow hair curling on her shoulders, pale and slender, and always carrying herself like a young lady mindful of her manners.

Pembaca manusia tahu "snow maiden" di s144 adalah **Amy**. Engine menautkannya ke **Beth**. Kasus ini diikuti di setiap pemberhentian, jadi kamu bisa melihat di mana kesalahannya terjadi.

Semua angka berasal dari menjalankan engine di Mac (yang punya model bahasa Inggris NaturalLanguage dan Apple Intelligence aktif), dengan kode di commit `530a040`. Di iPad hasilnya seharusnya sama. Di Simulator berbeda jauh, karena Simulator tidak punya model bahasa Inggris.

## Peta singkat

```
ReaderView ─► ReaderVM ─► RefCtrl ─► AnalysisRepo ─► AnalysisScheduleSvc
                                                         │
   FASE 1 (aturan, ±1,5 detik)                           ▼
   BookContent ─► SentenceText ─► WordTagSvc ─► MentionFinder ─► CastBuilder ─► MentionLinker
                                                                                      │
   FASE 2 (model, ±4 menit, di latar belakang)                                        ▼
                                                     TieBreakSvc ◄── LLMSvcFoundation, EvidenceGuard
                                                         │
                                                         ▼
                              AnalysisMapper + ContextPassagePicker ─► BookAnalysis
                                                         │
ReaderView ◄─ PageTextView ◄─ ReaderVM.loadMarks ◄─ RefCtrl.marks
```

**Fase 1** hanya memakai framework **NaturalLanguage** Apple (memberi label kata) ditambah aturan Swift biasa. **Fase 2** memakai **Foundation Models** (model bahasa di perangkat). Hasil fase 1 langsung ditampilkan. Hasil fase 2 menggantikannya setelah selesai.

## Tipe data yang lewat

| Tipe | Isi | File |
|---|---|---|
| `BookContent` | Seluruh buku: bab, paragraf, kalimat. Hasil parser EPUB, tidak pernah diubah engine | `Models/BookContent.swift` |
| `Sentence` | Satu kalimat: nomor paragraf dan rentang huruf di dalam paragraf | `Models/Sentence.swift` |
| `NumberedSentence` | Satu kalimat: nomor global (s0, s1, …) dan teksnya | `Models/AI/NumberedSentence.swift` |
| `SentenceTags`, `Token` | Label tiap kata di tiap kalimat: jenis kata, jenis nama, lemma, posisi | `Models/AI/SentenceTags.swift` |
| `ResolvedMention` | Satu penyebutan tokoh: kalimat, posisi, teks, bentuk (nama atau deskripsi), kata kepala, modifier, tokoh yang ditautkan, siapa yang memutuskan, dan apakah masih *undecided* | `Models/AI/ResolvedMention.swift` |
| `ResolvedEntity` | Satu tokoh di dalam engine: nomor (`key`), nama-namanya, label, kalimat pertama muncul, dan riwayat penggabungan (`mergeEdges`) | `Models/AI/ResolvedEntity.swift` |
| `ResolvedAnalysis` | Semua tokoh dan semua mention, ditambah hitungan panggilan model | `Models/AI/ResolvedAnalysis.swift` |
| `RulesPass` | Hasil fase 1 yang disimpan untuk fase 2: buku, kalimat bernomor, dan analisis | `Models/AI/RulesPass.swift` |
| `ModelSentence`, `ModelCandidate`, `LinkRequest`, `LinkChoice`, `NameGroupRequest`, `NameGroupChoice` | Pertanyaan ke model dan jawabannya | `Models/AI/` |
| `ChooseReferenceAnswer`, `GroupNamesAnswer`, `NameGroupItem` | Bentuk jawaban yang dipaksakan ke model (`@Generable`) | `Models/AI/` |
| `BookAnalysis`, `Entity`, `Mention`, `ContextPassage` | Hasil akhir dalam bentuk milik aplikasi, yang dibaca layar | `Models/` |
| `Mark`, `Page` | Satu tanda di satu halaman (simbol, garis bawah, sorotan), dan satu halaman | `Models/` |

Dua hal penting tentang posisi teks:
- **Engine menghitung posisi per kalimat**, misalnya "huruf ke-0 sampai ke-54 di s144".
- **Aplikasi menghitung posisi per paragraf**, misalnya "paragraf 98, mulai huruf ke-1266". `AnalysisMapper` (pemberhentian 9) yang menerjemahkan.

Satu konsep penting lagi: **"per kalimat" (anti-spoiler)**. Penggabungan tokoh dicatat beserta kalimat tempat penggabungan itu terungkap (`mergedAtSentence`). Jadi pertanyaan "mention ini milik siapa" selalu dijawab *sejauh pembaca sudah tahu di kalimat itu*, lewat `entityKey(of:asOf:)`.

---

## 1. Buku dibuka

**Masuk:** pembaca membuka Little Women.

**Fungsi**
- `Views/ReaderView.swift`: `.task { await readerVM.onAppear(viewport:) }` dijalankan saat halaman baca tampil. View ini juga meneruskan `readerVM.marks` ke `PageTurnView` dan meneruskan ketukan tanda ke `readerVM.markTapped`.
- `VM/ReaderVM.swift`
  - `onAppear(viewport:)` memulai dua hal sekaligus:
    1. Satu `Task` di latar belakang yang menjalankan `refCtrl.prepare()` (fase 1), lalu `refCtrl.refine()` (fase 2), lalu `loadMarks()` sekali lagi supaya tanda di halaman ikut hasil fase 2.
    2. Membuka buku dan menampilkan halaman (`showCurrentPage()`), tanpa menunggu engine.
  - `showCurrentPage()` menghitung halaman sekarang, mengosongkan `marks`, lalu memanggil `loadPages(around:)`.
  - `loadPages(around:)` memuat halaman di sekitar halaman sekarang, lalu `loadMarks()`.
  - `show(_:highlighting:)` dipakai saat pembaca pindah halaman. Isinya sama: `loadPages(around:)`.
  - Fungsi lain di `ReaderVM` (menu, pencarian, pengaturan, daftar isi) bukan bagian engine. Satu-satunya hubungan: mengubah pengaturan (termasuk toggle **Symbols**) memanggil `showCurrentPage()`, jadi tanda dihitung ulang.

**Keluar:** dua permintaan ke `RefCtrl`: `prepare()`/`refine()` (latar belakang) dan `marks(on:...)` (per halaman, pemberhentian 10).

**Knob:** tidak ada.

## 2. Meminta analisis: RefCtrl → AnalysisRepo → AnalysisScheduleSvc

**Masuk:** `bookID` buku yang dibuka.

**Fungsi**
- `Ctrl/RefCtrl.swift`
  - `prepare()` memanggil `analysisRepo.analysis(for:)` dan membuang hasilnya. Tujuannya hanya memanaskan cache supaya fase 1 mulai secepatnya.
  - `refine()` memanggil `analysisRepo.refinedAnalysis(for:)` (fase 2).
- `Repo/AnalysisRepo.swift` (sebuah `actor`: hanya satu pemanggil yang mengubah isinya pada satu waktu)
  - `init(bookContentRepo:analysisScheduleSvc:)` menyimpan dua dependensinya. Dibuat sekali di `App/iReadApp.swift`.
  - `analysis(for:)` mengembalikan hasil **terbaru** yang ada di `latest`. Kalau belum ada, ia menunggu fase 1 (`rulesPass(for:)`), memetakannya ke `BookAnalysis`, lalu menyimpannya.
  - `refinedAnalysis(for:)` menjalankan fase 2 sekali per buku (disimpan di `refinements`), lalu **mengganti** `latest` dengan hasilnya.
  - `rulesPass(for:)` (`private`) mengambil teks buku dari `BookContentRepo`, lalu menjalankan fase 1 sekali per buku (disimpan di `passes`).

  Semua kerja berat dijalankan dengan `Task.detached`, jadi di luar actor dan tidak memblokir pemanggil lain.
- `Repo/BookContentRepo.swift`: `content(for:)` mem-parse EPUB bawaan sekali (`EPUBParseSvc.parse`) dan menyimpan hasilnya. Parser memecah teks jadi kalimat dengan `NLTokenizer` dari NaturalLanguage.
- `Svc/AI/AnalysisScheduleSvc.swift` adalah **seluruh pipeline dalam satu file**. Baca file ini dulu:
  - `rulesPass(for:)`: fase 1, pemberhentian 3 sampai 7, berurutan.
  - `analysis(from:)`: hasil fase 1 → `BookAnalysis` (pemberhentian 9).
  - `refinedAnalysis(from:)`: fase 2 (pemberhentian 8), lalu → `BookAnalysis` (pemberhentian 9).

**Keluar:** `BookContent` masuk ke `rulesPass(for:)`.

**Knob:** tidak ada.

## 3. BookContent → kalimat bernomor

**Masuk:** `BookContent`. Untuk Little Women: 52 bab (sesuai daftar isi EPUB), 4278 paragraf, dan 10.163 kalimat.

Contoh, kalimat s144 di dalam `BookContent`:
- `Sentence`: paragraf 98, rentang `{1266, 168}` di dalam paragraf
- `Paragraph` 98: bab 3 ("CHAPTER ONE PLAYING PILGRIMS"), rentang `{6497, 1510}` di dalam teks bab

**Fungsi:** `Rules/AI/SentenceText.swift`
- `of(_:in:)` mengambil teks satu kalimat: posisi paragraf ditambah posisi kalimat, lalu potong dari teks bab. Untuk s144: 6497 + 1266 = huruf ke-7763 di teks bab.
- `numbered(in:)` mengubah semua kalimat jadi `NumberedSentence`. Nomor kalimat = urutannya di seluruh buku.

**Keluar:** `[NumberedSentence]`, 10.163 kalimat. Contoh:
- `s141`: "Elizabeth, or Beth, as everyone called her, was a rosy, smooth-haired, bright-eyed girl of thirteen, …"
- `s144`: "A regular snow maiden, with blue eyes, and yellow hair curling on her shoulders, …"

**Knob:** tidak ada.

## 4. Kalimat → label kata (Step 2)

**Masuk:** `[NumberedSentence]`.

**Fungsi:** `Svc/AI/WordTagSvc.swift`
- `tag(_:)` memeriksa apakah model bahasa Inggris tersedia. Kalau ya, semua kalimat dilabeli dengan NLTagger; kalau tidak, dengan aturan cadangan.
- `hasEnglishModels()` (`private`) mengetes kalimat "John walked to London." Kalau "John" dikenali sebagai `PersonalName`, model tersedia.
- `tokensByNaturalLanguage(_:tagger:)` (`private`) memberi tiap kata tiga label dari `NLTagger`:
  - **jenis kata** (`lexicalClass`): Noun, Verb, Adjective, Determiner, …
  - **jenis nama** (`nameType`): PersonalName, PlaceName, OrganizationName, atau tidak ada
  - **lemma**: bentuk dasar ("eyes" → "eye", "called" → "call")

  NLTagger memotong kata bertanda hubung ("smooth" + "haired"). Fungsi ini menyambungnya kembali jadi satu kata ("smooth-haired") kalau knob `stitchHyphenatedWords` aktif.
- `tokensByRules(_:)` (`private`) adalah cadangan tanpa model: jenis kata ditebak dari daftar kata di knob, dan kata berhuruf kapital (bukan di awal kalimat) dianggap nama.
- `makeToken(_:in:range:lexicalClass:name:lemma:)` (`private`) membuat satu `Token` dan mengubah posisinya ke hitungan huruf UTF-16 (satuan posisi yang dipakai seluruh aplikasi).

**Keluar:** `SentenceTags`, satu daftar `Token` per kalimat. Contoh `teks/jenis/nama/lemma@posisi`:

```
s141: Elizabeth/Noun/PersonalName/elizabeth@0  or/Conjunction/or@11  Beth/Noun/PersonalName/beth@14
      as/Preposition/as@20  … was/Verb/be@44  a/Determiner/a@48  rosy/Noun/rosy@50
      smooth-haired/Adjective/smooth-haired@56  bright-eyed/Adjective/bright-eyed@71  girl/Noun/girl@83 …
s144: A/Determiner/a@0  regular/Adjective/regular@2  snow/Noun/snow@10  maiden/Noun/maiden@15
      with/Preposition/with@23  blue/Adjective/blue@28  eyes/Noun/eye@33  and/Conjunction/and@39
      yellow/Adjective/yellow@43  hair/Noun/hair@50  curling/Verb/curl@55 …
```

Perhatikan "rosy" dilabeli **Noun**, bukan Adjective. Itu keputusan NLTagger, bukan kode kita.

**Knob:** `WordTagKnobs` di file yang sama. Hanya berpengaruh di jalur cadangan, kecuali yang terakhir:
- `determiners`, `pronouns`, `prepositions`, `conjunctions`: daftar kata untuk menebak jenis kata
- `stitchHyphenatedWords`: sambung kata bertanda hubung (berlaku di kedua jalur)

## 5. Label kata → mention (Step 3a)

**Masuk:** `[NumberedSentence]` dan `SentenceTags`.

**Fungsi:** `Rules/AI/MentionFinder.swift`
- `mentions(in:tags:)` menggabungkan **nama** dan **deskripsi** dari tiap kalimat, lalu mengurutkannya menurut posisi.
- `names(in:tokens:)` (`private`) mencari deret kata yang semuanya "kata nama" dan saling bersambung ("Mr. March", "Louisa May Alcott"). Deret yang isinya cuma gelar ("Mr.") dibuang.
- `joinsName(_:_:in:)` (`private`): dua kata tergabung kalau dipisah satu spasi, atau kalau kata pertama gelar dan dipisah ". ".
- `isTitle(_:)` (`private`): apakah kata ada di knob `titles`.
- `isNameWord(_:)` (`private`): kata dianggap nama kalau jenis namanya ada di `personNameTypes`, atau kalau kata keluarga berhuruf kapital ("Father", "Marmee"). Kata kelompok ("everyone", "girls") selalu ditolak.
- `descriptions(in:tokens:)` (`private`) mencari pola **determiner + (kata sifat/benda)… + kata kepala orang**, misalnya "a rosy, smooth-haired, bright-eyed girl". Kalau sesudahnya ada "with …", kata sifat/benda di frasa itu ikut jadi modifier ("…, with blue eyes, and yellow hair").
- `isPersonHead(_:)` (`private`): kata kepala harus ada di knob `personHeads` dan bukan kata kelompok.
- `mention(_:in:form:head:modifiers:)` (`private`) membuat satu `ResolvedMention`.
- `textBetween(_:_:in:)` (`private`) mengambil teks di antara dua kata.
- Dipakai juga: `Rules/AI/NameKey.swift`, `NameKey.of(_:)`, yang menormalkan nama jadi kunci ("Mr. March" → "mr march"). Kunci ini yang dibandingkan, bukan teks aslinya.

**Keluar:** `[ResolvedMention]`, 5679 mention di seluruh buku (5016 nama). Di s91–s175 ada 58 mention: 47 nama dan 11 deskripsi. Semua deskripsinya:

| Kalimat | Teks | Kepala | Modifier |
|---|---|---|---|
| s115 | a little girl | girl | little |
| s115 | a young lady | lady | young |
| s119 | a girl | girl | |
| s120 | a boy | boy | |
| s122 | a poky old woman | woman | poky, old |
| s140 | a girl | girl | |
| s140 | a woman | woman | |
| s141 | a rosy, smooth-haired, bright-eyed girl | girl | rosy, smooth-haired, bright-eyed |
| s144 | A regular snow maiden, with blue eyes, and yellow hair | maiden | regular, snow, blue, eye, yellow, hair |
| s154 | the man | man | |
| s175 | a child | child | |

Nama di s141: "Elizabeth" (kunci `elizabeth`) dan "Beth" (kunci `beth`). Di s143: "Amy".

**Knob:** `MentionFinderKnobs`
- `titles`: gelar yang boleh menempel ke nama ("mr.", "mrs.", "aunt", …)
- `personNameTypes`: jenis nama dari NLTagger yang dianggap orang
- `familyTerms`: kata keluarga yang dianggap nama bila berhuruf kapital
- `personHeads`: kata kepala yang dianggap orang, beserta kelompok sinonimnya ("lad" → "boy", "maiden" → "girl"). Kelompok ini dipakai lagi di pemberhentian 7
- `groupWords`: kata kelompok yang bukan satu orang ("girls", "everyone")
- `determiners`: kata pembuka deskripsi
- `descriptionWordClasses`, `withPhraseWordClasses`: jenis kata yang boleh ada di dalam deskripsi dan di frasa "with …"
- `allowWithPhrase`, `maxWithPhraseWords`: frasa "with …" boleh ikut, dan sampai berapa kata

## 6. Mention → daftar tokoh (Step 3b)

**Masuk:** `[ResolvedMention]` dan `[NumberedSentence]`.

**Fungsi:** `Rules/AI/CastBuilder.swift`
- `cast(from:sentences:)`
  1. Setiap kunci nama yang muncul minimal `minNameCount` kali menjadi satu tokoh. Nomornya urut kemunculan pertama, dan labelnya ejaan yang paling sering muncul.
  2. Lalu ia mencari pola alias di kalimat yang sama ("Elizabeth, or Beth") dan menggabungkan kedua nama.
- `joinNames(_:_:at:decidedBy:in:)` (`private`) menggabungkan dua nama:
  - kalau keduanya sudah tokoh, yang muncul belakangan digabung ke yang lebih awal;
  - kalau baru satu yang tokoh, nama lainnya ditambahkan ke tokoh itu.
- `isAlias(between:and:in:)` (`private`): teks di antara dua nama cocok dengan salah satu pola di knob `aliasConnectors`.
- `mostFrequentText(of:)` (`private`): ejaan yang paling sering.
- Dipakai juga, di `Rules/AI/ResolvedAnalysis+Names.swift`:
  - `entityKey(forName:)` mencari tokoh yang memiliki kunci nama itu.
  - `addName(_:to:at:)` menambahkan nama ke tokoh, beserta kalimat sejak kapan nama itu berlaku.
- Dipakai juga, di `Rules/AI/ResolvedAnalysis+Merges.swift`: `merge(_:into:at:decidedBy:)` (lihat pemberhentian 7).

**Keluar:** `[ResolvedEntity]`, 168 tokoh bernama. Yang muncul di contoh:

| Nomor | Label | Nama (sejak kalimat) | Pertama muncul |
|---|---|---|---|
| #3 | Beth | BETH (s20), Elizabeth (s141) | s20 |
| #6 | Jo | Jo (s67) | s67 |
| #7 | Amy | Amy (s70) | s70 |
| #8 | Father | Father (s71) | s71 |
| #9 | Mother | Mother (s71) | s71 |
| #10 | Meg | Meg (s74) | s74 |
| #11 | Papa | Papa (s92) | s92 |
| #12 | Brown | brown (s137) | s137 |

Dua hal yang perlu dicatat untuk tuning:
- **Beth pertama "muncul" di s20, yaitu di daftar isi** ("CHAPTER SIX BETH FINDS THE PALACE BEAUTIFUL"), bukan di cerita. Daftar isi ikut dianggap teks buku.
- **#12 "Brown" bukan tokoh.** Itu dari s137, "Jo was very tall, thin, and **brown**", yang dilabeli sebagai nama oleh NLTagger.

"Elizabeth" tergabung ke Beth karena pola `, or ` di s141 cocok dengan `aliasConnectors`.

**Knob:** `CastBuilderKnobs`
- `minNameCount`: berapa kali sebuah nama harus muncul agar jadi tokoh
- `aliasConnectors`: pola teks di antara dua nama yang berarti orang yang sama (", or", ", called", ", known as")

## 7. Mention + tokoh → analisis aturan (Step 3c)

**Masuk:** `[ResolvedMention]`, `[ResolvedEntity]` (cast), dan `[NumberedSentence]`.

**Fungsi:** `Rules/AI/MentionLinker.swift`
- `link(_:to:sentences:)` membaca semua mention **sesuai urutan baca**, lalu memutuskan tokohnya:
  - **Nama** → tokoh yang punya nama itu, asalkan nama itu sudah berlaku di kalimat tersebut (`knownName`).
  - **Deskripsi tepat sesudah nama** (apositif, misalnya "Jo, who was …") → tokoh nama itu (`appositionTarget`). Kalau deskripsi itu juga cocok dengan tokoh-deskripsi lain yang tak bernama, keduanya digabung.
  - **Deskripsi yang cocok kuat dengan satu deskripsi sebelumnya** → tokoh deskripsi itu (`bestMatch`).
  - **Selain itu** → tokoh baru yang hanya dikenal lewat deskripsi ini (`openDescribedEntity`), dan mention ditandai `isUndecided = true`. Fase 2 yang akan mencoba memutuskannya.

  Semua mention yang dapat tokoh ditandai `decidedBy = .rule`.
- `knownName(_:in:)` (`private`): tokoh yang memiliki kunci nama ini sejak kalimat ini atau sebelumnya.
- `appositionTarget(of:in:text:)` (`private`): nama terakhir sebelum deskripsi di kalimat yang sama, kalau teks di antaranya cocok dengan knob `appositionConnectors`.
- `Match` (`private`): hasil pencocokan, yaitu tidak ada, satu tokoh, atau seri.
- `bestMatch(for:in:)` (`private`) memberi skor terhadap semua deskripsi sebelumnya. Hanya menang kalau tepat satu tokoh punya skor tertinggi.
- `strongScore(_:_:)` (`private`) menghitung skor:
  - **kepala**: sama persis → `sameHeadScore`; satu kelompok sinonim (dari `MentionFinderKnobs.personHeads`) → `synonymScore`; selain itu tidak cocok
  - **modifier**: tiap modifier yang sama → `sharedModifierScore`
  - **lolos kalau** total ≥ `strongMatchTotal` **dan** skor modifier ≥ `strongMatchModifiers`
- `comparable(_:)` (`private`) menormalkan modifier sebelum dibandingkan: pecah di tanda hubung, huruf kecil, dan buang akhiran "-ed" untuk kata yang panjangnya minimal `minLengthToStripEd`.
- `openDescribedEntity(for:in:)` (`private`) membuat tokoh baru yang hanya punya deskripsi.
- `dropSmallDescribedEntities(in:)` membuang tokoh-deskripsi yang mention-nya kurang dari `minMentionsForDescribedEntity` dan tidak pernah digabung. Fungsi ini dipanggil di akhir fase 2, bukan di sini.
- Dipakai juga, di `Rules/AI/ResolvedAnalysis+Merges.swift`:
  - `linkedMentions`: mention yang sudah punya tokoh
  - `entity(_:)`: cari tokoh berdasarkan nomor
  - `entityKey(of:asOf:)`: tokoh sebuah mention **sejauh yang diketahui di kalimat tertentu**
  - `finalKey(of:)`: tokoh akhir setelah semua penggabungan
  - `merge(_:into:at:decidedBy:)`: catat bahwa tokoh A adalah tokoh B mulai kalimat tertentu
  - `follow(_:upTo:)` (`private`): ikuti rantai penggabungan sampai kalimat tertentu
- Dipakai juga, di `Rules/AI/ResolvedEntity+Names.swift`: `isNamed`, yaitu apakah tokoh punya minimal satu nama.

**Keluar:** `ResolvedAnalysis`. Di seluruh buku: 5679 mention, 5405 tertaut, 405 *undecided*, dan 573 tokoh (168 bernama dan 405 tokoh-deskripsi).

Hasil di contoh:

| Kalimat | Mention | Ditautkan ke | Undecided |
|---|---|---|---|
| s115 | a little girl | tokoh baru #171 "a little girl" | ya |
| s115 | a young lady | tokoh baru #172 | ya |
| s119 | a girl | tokoh baru #173 | ya |
| s120 | a boy | tokoh baru #174 | ya |
| s122 | a poky old woman | #170 "a nervous, fussy old lady" (dari s87) | tidak |
| s140 | a girl / a woman | tokoh baru #175 / #176 | ya |
| s141 | Elizabeth, Beth | #3 Beth | tidak |
| s141 | a rosy, smooth-haired, bright-eyed girl | tokoh baru #177 | ya |
| s143 | Amy | #7 Amy | tidak |
| **s144** | **A regular snow maiden, …** | **#177, deskripsi Beth dari s141** | tidak |
| s154 | the man | tokoh baru #178 | ya |
| s175 | a child | tokoh baru #179 | ya |

**Kenapa s141 tidak langsung ke Beth?** Teks di antara "Beth" dan deskripsinya adalah ", as everyone called her, was ". Itu tidak cocok dengan `appositionConnectors`, yang hanya mengenal "," dan ", who was". Jadi deskripsinya jadi tokoh baru #177.

**Kenapa s144 ikut #177, bukan Amy?** Skornya terhadap deskripsi s141:
- kepala "maiden" dan "girl" satu kelompok sinonim → `synonymScore` = **1,5**
- modifier s141 setelah dinormalkan: rosy, smooth, **hair** ("haired" dibuang "-ed"-nya), bright, eyed ("eyed" hanya 4 huruf, jadi tidak dipotong)
- modifier s144: regular, snow, blue, eye, yellow, **hair**
- satu modifier sama ("hair") → **2,0**
- total **3,5**, tepat di ambang `strongMatchTotal` = 3,5, dan skor modifier tepat di `strongMatchModifiers` = 2,0 → lolos

Satu kata "hair" (Beth berambut halus, Amy berambut kuning) cukup untuk menautkan keduanya. Sementara itu "Amy" di s143 tidak ikut dipertimbangkan, karena aturan ini hanya membandingkan deskripsi dengan deskripsi.

**Knob:** `MentionLinkerKnobs`
- `sameHeadScore`, `synonymScore`, `sharedModifierScore`: bobot skor
- `strongMatchTotal`, `strongMatchModifiers`: ambang kecocokan. Menaikkan `strongMatchTotal` ke 4,0 akan memutus kasus s144, tapi juga pasangan benar yang skornya pas-pasan
- `minMentionsForDescribedEntity`: batas tokoh-deskripsi kecil yang dibuang di akhir fase 2
- `appositionConnectors`: pola apositif. Menambahkan pola seperti ", as …, was" akan menautkan s141 langsung ke Beth
- `minLengthToStripEd`: panjang minimal kata agar "-ed" dibuang. Dengan nilai 4, "eyed" jadi "ey", tetap tidak sama dengan "eye"

## 8. Fase 2: model menyempurnakan (Step 5)

**Masuk:** `ResolvedAnalysis` dari fase 1, `[NumberedSentence]`, dan sebuah `LLMSvc`.

**Fungsi**
- `Svc/AI/ModelAvailSvc.swift`
  - `isFoundationModelsAvailable`: `true` kalau knob `LLMKnobs.isEnabled` aktif dan Apple Intelligence siap di perangkat.
  - `makeLLMSvc()`: mengembalikan `LLMSvcFoundation` kalau tersedia, `LLMSvcUnavailable` kalau tidak.
- `Svc/AI/LLMSvc.swift`
  - `LLMSvc` adalah **protokol**: daftar kemampuan yang harus dimiliki penyedia model (`isAvailable`, `contextSentenceCount`, `maxCandidates`, `allowsCall(callsSoFar:)`, `groupNames(_:)`, `chooseReference(_:)`). Engine hanya bicara ke protokol ini, jadi model bisa diganti tanpa mengubah engine.
  - `LLMSvcUnavailable` menjawab "tidak tersedia" untuk semuanya. Akibatnya fase 2 hanya membuang tokoh-deskripsi kecil.
- `Svc/AI/TieBreakSvc.swift`
  - `settle(_:sentences:llm:)`: kalau model tersedia, jalankan `groupNames`, lalu `settleDescription` untuk setiap mention `isUndecided`, berurutan. Terakhir `MentionLinker.dropSmallDescribedEntities`.
  - `groupNames(in:texts:llm:)` (`private`) mengirim nama pertama tiap tokoh dan kalimat tempat nama itu pertama muncul ke model, lalu bertanya: nama mana yang orang yang sama? Kelompok yang lolos `EvidenceGuard` digabung, berlaku sejak kalimat buktinya.
  - `settleDescription(at:in:texts:llm:)` (`private`) mengirim jendela kalimat (kalimat mention dan `contextSentenceCount` kalimat sebelumnya) beserta daftar kandidat, lalu bertanya: frasa ini merujuk ke kandidat mana? Kalau jawabannya lolos `EvidenceGuard`, tokoh-deskripsi digabung ke kandidat itu, berlaku sejak deskripsi itu pertama muncul. Mention ditandai `decidedBy = .model` dan `isUndecided = false`.
  - `candidateCharacters(for:excluding:window:in:limit:)` (`private`) memilih sampai `maxCandidates` kandidat: tokoh yang disebut paling akhir sebelum mention, mendahulukan yang ada di jendela. Label kandidat: nama tokoh, atau teks deskripsinya kalau tak bernama.
- `Svc/AI/LLMSvcFoundation.swift`
  - `LLMSvcFoundation.allowsCall(callsSoFar:)`: masih di bawah `maxCallsPerRun`?
  - `chooseReference(_:)`: satu sesi model baru per pertanyaan, jawaban dipaksa berbentuk `ChooseReferenceAnswer` (nomor kandidat dan nomor kalimat bukti).
  - `groupNames(_:)`: nama dikirim per `maxNamesPerCall`, jawaban berbentuk `GroupNamesAnswer` (daftar kelompok dan kalimat bukti). Panggilan yang gagal dilewati.
  - `options(maximumTokens:)` (`private`) menerjemahkan knob `sampling` dan `temperature` ke `GenerationOptions`.
  - `LLMKnobs.chooseReferencePrompt(_:)` dan `groupNamesPrompt(names:sentences:)` menyusun teks pertanyaan. `numbered(_:)` (`private`) menulis kalimat sebagai "[141] Elizabeth, or Beth, …".
  - `Sampling`: cara memilih kata (`greedy`, `topK`, `probability`).
- `Rules/AI/EvidenceGuard.swift` memeriksa setiap jawaban model sebelum dipercaya:
  - `accepts(_: LinkChoice, for:)`: nomor kandidat valid, kalimat bukti ikut dikirim dan tidak sesudah mention, dan nama kandidat muncul sebagai kata utuh **di salah satu kalimat yang dikirim**.
  - `accepts(_: NameGroupChoice, for:)`: semua nama memang ditanyakan, dan minimal dua nama didukung kalimat bukti.
  - `supportedNames(_:for:)`: nama yang muncul di kalimat bukti, berdekatan (tidak lebih dari `maxWordsBetweenGroupedNames` kata), dan tidak dipisah kata seperti "and".
  - `appears(_:in:)` dan `wordRange(of:in:)` (`private`): cari kata utuh, tanpa membedakan huruf besar-kecil.

**Keluar:** `ResolvedAnalysis` yang sudah disempurnakan. Di Mac: 240 detik, 150 panggilan (batas `maxCallsPerRun`, sementara ada 405 *undecided*), dan **0 nama yang digabung**. Yang diputuskan model di contoh:

| Kalimat | Mention | Keputusan model | Benar? |
|---|---|---|---|
| s115 | a little girl | Jenny Snow | Salah, dan **spoiler**: Jenny Snow baru muncul di s1504. Lihat penjelasan di bawah |
| s120 | a boy | tetap #174 | Tidak berubah yang terlihat |
| s140 | a girl | Jo | Benar |
| s140 | a woman | Jo | Benar |
| s141 | a rosy, smooth-haired, bright-eyed girl | Beth | Benar |
| s154 | the man | Jo | Benar ("I'm the man of the family", kata Jo) |

**Kenapa s115 jadi Jenny Snow (bug spoiler):**
1. Di fase 1, "a young lady" di s115 menjadi tokoh-deskripsi #172, dan "young lady" sesudahnya ikut tertaut ke sana. Di s1504 ("Jenny Snow, a satirical young lady") pola apositif menggabungkan #172 ke Jenny Snow **mulai s1504**. Sejauh ini benar.
2. Di fase 2, model memasangkan "a little girl" (s115) ke kandidat "a young lady" (#172). Masuk akal, karena keduanya ada di kalimat yang sama dan merujuk ke Jo.
3. `merge(_:into:at:)` di `Rules/AI/ResolvedAnalysis+Merges.swift` mencari tujuan dengan `finalKey(of:)`, yang mengikuti **semua** penggabungan, termasuk yang baru terjadi di s1504. Jadi "a little girl" digabung langsung ke Jenny Snow, berlaku mulai s115.

Akibatnya pembaca di halaman 6 bisa melihat nama yang baru diperkenalkan ratusan halaman kemudian. Perbaikannya ada di `merge`: tujuan harus dicari sejauh kalimat penggabungan (`follow(_:upTo:)` dengan kalimat itu), bukan sampai akhir buku.

**Efek ke s144:** model menggabungkan #177 ke Beth mulai s141. Karena s144 sudah tertaut ke #177 (pemberhentian 7), s144 sekarang ikut jadi **Beth**. Kesalahan aturan di pemberhentian 7 terbawa, padahal model tidak pernah ditanya soal s144.

**Knob**
- `LLMKnobs` di `LLMSvcFoundation.swift`:
  - `isEnabled`: matikan fase model sepenuhnya
  - `groupNamesInstructions`, `chooseReferenceInstructions`: instruksi ke model
  - `chooseReferencePrompt`, `groupNamesPrompt`: format pertanyaan
  - `contextSentenceCount`: berapa kalimat sebelum mention ikut dikirim
  - `maxCandidates`: berapa kandidat ditawarkan
  - `maxNamesPerCall`: berapa nama per panggilan gabung nama
  - `sampling`, `temperature`: cara model memilih jawaban
  - `maxChooseReferenceTokens`, `maxGroupNamesTokens`: panjang jawaban maksimum
  - `maxCallsPerRun`: batas panggilan per buku
- `EvidenceKnobs` di `EvidenceGuard.swift`:
  - `maxWordsBetweenGroupedNames`: seberapa dekat dua nama di kalimat bukti
  - `separatePeopleWords`: kata yang berarti dua orang berbeda ("and", "&", "with", "nor")

## 9. Analisis → BookAnalysis (hasil untuk aplikasi)

**Masuk:** `ResolvedAnalysis` (dari fase 1 atau fase 2) dan `BookContent`.

**Fungsi**
- `Rules/AI/AnalysisMapper.swift`
  - `map(_:content:)`
    1. Untuk tiap mention, ambil tokohnya **per kalimat** (`entityKey(of:asOf:)`).
    2. Simpan hanya tokoh dengan minimal `minimumMentions` mention (dan bernama, kalau `onlyNamed`).
    3. Urutkan tokoh menurut kalimat pertama muncul, lalu bagikan simbol dari daftar `symbols` sesuai urutan.
    4. Ubah posisi mention dari per kalimat ke **per paragraf**: posisi kalimat di paragraf + posisi mention di kalimat.
    5. Minta `ContextPassagePicker` memilih kalimat kutipan untuk garis bawah.
  - `passage(at:in:)` (`private`): nomor kalimat → `ContextPassage` (paragraf, rentang, dan teks kalimat).
  - `id(of:)` (`private`): nomor tokoh → id aplikasi ("character-3").
  - `summary` tiap `Entity` diisi teks kalimat pertama tokoh itu muncul.
- `Rules/AI/ContextPassagePicker.swift`
  - `sentence(for:among:in:)`: hanya untuk bentuk mention di knob `underlinedForms` (sekarang hanya deskripsi). Dari mention tokoh yang sama **sebelum** frasa ini, pilih:
    1. deskripsi dengan kepala sama dan modifier paling banyak sama (seri → yang paling awal);
    2. kalau tidak ada, kemunculan pertama tokoh itu;
    3. kalau tidak ada mention sebelumnya sama sekali, `nil`: frasa ini pengenalnya sendiri, jadi tidak digaris bawahi.
  - `overlap(_:_:)` (`private`): jumlah modifier yang sama.

**Keluar:** `BookAnalysis`.

| | Fase 1 | Fase 2 |
|---|---|---|
| Tokoh (dengan simbol) | 23 | 25 |
| Mention | 4249 | 4392 |
| Bergaris bawah | 164 | 275 |

Simbol tokoh di contoh:

| Tokoh | Fase 1 | Fase 2 |
|---|---|---|
| Beth | `circle.fill` | `square.fill` |
| Jo | `triangle.fill` | `diamond.fill` |
| Amy | `diamond.fill` | `hexagon.fill` |
| Meg | `heart.fill` | `pentagon.fill` |
| Mother | `star.fill` | `star.fill` |
| Marmee | `moon.fill` | `moon.fill` |

Simbol berganti di antara fase. Di fase 2, "Laurence" lolos `minimumMentions` dan muncul paling awal (dari daftar isi), jadi urutan semua tokoh bergeser satu.

Mention di contoh yang punya garis bawah:

| Mention | Tokoh | Kutipan (`passage`) |
|---|---|---|
| s122 "a poky old woman" (fase 1 dan 2) | a nervous, fussy old lady | s87 "How would you like to be shut up for hours with a nervous, fussy old lady, …" |
| s140 "a girl", "a woman" (fase 2) | Jo | "Christmas won't be Christmas without any presents," grumbled Jo, … (kemunculan pertama Jo) |
| s141 "a rosy, smooth-haired, bright-eyed girl" (fase 2) | Beth | "CHAPTER SIX BETH FINDS THE PALACE BEAUTIFUL" (kemunculan pertama Beth, di daftar isi) |
| s144 "A regular snow maiden, …" (fase 2) | **Beth** | sama, baris daftar isi |
| s154 "the man" (fase 2) | Jo | kemunculan pertama Jo |

Di fase 1, deskripsi s141 dan s144 **tidak tampil sama sekali**. Keduanya milik tokoh #177, yang hanya punya 2 mention (di bawah `minimumMentions` = 20).

Contoh posisi s144 di `BookAnalysis` (fase 2): `Mention(entityID: "character-3", paragraph: 98, range: {1266, 54}, passage: …)`.

**Knob**
- `AnalysisMapperKnobs`:
  - `minimumMentions`: tokoh dengan mention lebih sedikit tidak tampil
  - `onlyNamed`: hanya tokoh bernama
  - `symbols`: daftar simbol, dibagikan sesuai urutan kemunculan
- `ContextPassageKnobs.underlinedForms`: bentuk mention yang digaris bawahi (`.description`, bisa ditambah `.name`)

## 10. BookAnalysis → tanda per halaman

**Masuk:** satu `Page` (nomor, bab, rentang huruf di teks bab, dan teksnya) dan `BookAnalysis` terbaru.

**Fungsi**
- `VM/ReaderVM.swift`, `loadMarks()` (`private`): untuk setiap halaman yang sedang dimuat, minta tanda ke `RefCtrl`. Hasilnya dibuang kalau pembaca sudah pindah halaman selama menunggu.
- `Ctrl/RefCtrl.swift`
  - `marks(on:highlighting:includingSymbols:)` memeriksa semua mention dan, kalau berada di halaman ini, membuat:
    - **garis bawah** di seluruh frasa, kalau mention punya `passage`;
    - **simbol** di huruf pertama frasa, kalau toggle Symbols aktif;
    - **sorotan** di kalimat kutipan, kalau mention ini yang sedang dibuka lewat "Jump to Passage".
  - `pageRange(paragraph:range:on:in:)` (`private`) mengubah posisi per paragraf jadi posisi di halaman: posisi paragraf di bab + posisi di paragraf, lalu dikurangi awal halaman. Kalau tidak beririsan dengan halaman, `nil`.
  - `entity(forMention:)` dan `passage(forMention:)` dipakai saat tanda diketuk (pemberhentian 11).

Contoh s144: paragraf 98 mulai di huruf ke-6497 bab, dan mention mulai di huruf ke-1266 paragraf. Jadi mention ada di huruf ke-**7763** teks bab. Kalau halaman yang tampil mulai di huruf ke-X teks bab, simbol diletakkan di huruf ke-(7763 − X) halaman itu.

**Keluar:** `[Mark]` per halaman, disimpan di `ReaderVM.marks` dan diteruskan `ReaderView` → `PageTurnView` → `PageTextView`.

**Knob:** tidak ada di sini.

## 11. Tanda → layar

**Masuk:** `Page` dan `[Mark]` halaman itu.

**Fungsi**
- `Views/PageTextView+iOS.swift`
  - `init(page:settings:bodyFontSize:marks:onEdgeTapped:onMarkTapped:)` menyusun teks halaman dan membuat tombol simbol.
  - `attributedText()` (`private`) memberi gaya teks: garis bawah titik-titik untuk `.underline`, latar kuning untuk `.highlight`.
  - `addSymbolButtons()` (`private`) membuat satu tombol kecil per `.symbol`, dengan gambar SF Symbol dan warna dari `SymbolPalette`.
  - `symbolFrame(for:)` (`private`) menaruh simbol sedikit di atas huruf pertama frasa. Area ketuknya minimal 44 poin.
  - `layoutSubviews()` mengatur ulang posisi teks dan simbol saat ukuran berubah.
  - `tapped(_:)` (`private`) membedakan ketukan di tepi halaman (pindah halaman) dari ketukan di teks.
- `Rules/SymbolPalette.swift`, `color(forSymbol:)`: warna diambil dari posisi simbol di `AnalysisMapperKnobs.symbols`, jadi simbol yang sama selalu berwarna sama.
- `VM/ReaderVM.swift`, `markTapped(_:at:)`: simbol membuka kartu tokoh (`SymCardView`); garis bawah membuka kartu kutipan (`RefCardView`) dengan teks dari `RefCtrl.passage(forMention:)` dan halaman tempat kutipan itu berada.

**Keluar:** di halaman 7, "Elizabeth" dan "Beth" di s141 mendapat simbol Beth, "Amy" di s143 simbol Amy, dan "A regular snow maiden" di s144 **simbol Beth dengan garis bawah**. Diketuk, kartunya menampilkan baris daftar isi "CHAPTER SIX BETH FINDS THE PALACE BEAUTIFUL". Itu terjadi setelah fase 2 selesai; sebelumnya s141 dan s144 tidak bertanda apa pun.

**Knob:** `SymbolPaletteKnobs`
- `colors`: palet warna
- `fallback`: warna untuk simbol yang tidak dikenal

---

## Data pembanding: LitBank

Semua angka di atas berasal dari hasil engine sendiri, jadi benar atau salahnya dinilai dengan mata. LitBank memberi label buatan manusia untuk awal Little Women. Dengan label itu, hasil engine bisa dihitung benar dan salahnya.

Berkas ada di `App/Resources/litbank/`. Datanya dari <https://github.com/dbamman/litbank> (buku nomor 514 di Project Gutenberg), berlisensi CC BY 4.0, dan `README.md` LitBank ikut disimpan untuk atribusi.

**Cakupan.** Hanya 2.014 kata pertama yang diberi label. Itu sekitar separuh Bab 1 (4.103 kata) dan berakhir di adegan Beth menawarkan uang satu dolarnya untuk sarung tangan Marmee. Empat saudari sudah muncul di bagian ini, jadi cukup untuk membandingkan mention mereka. Skornya tetap dari sampel kecil dan belum mewakili seluruh buku.

| Berkas | Isi |
|---|---|
| `514_little_women.txt` | Teks yang diberi label (85 baris), sudah ditokenisasi |
| `514_little_women.entities.tsv` | Satu token per baris dengan tag BIO: PER (orang), FAC, GPE, LOC, VEH, ORG. Lapisan pertama punya 119 awal span PER; entitas bersarang ada di kolom berikutnya |
| `514_little_women.coref.conll` | Format CoNLL, satu token per baris. Kolom terakhir menandai kelompok yang menunjuk orang atau benda yang sama, termasuk kata ganti |
| `514_little_women.events.tsv` | Satu token per baris, ditandai `EVENT` atau `O` |
| `514_little_women.quotations.ann` | Daftar kutipan dialog (`QUOTE`) dengan posisi tokennya |
| `README.md` | Penjelasan LitBank dan lisensinya |

**Teks yang diberi label tidak sama dengan teks EPUB.** Tokenisasi memisahkan tanda baca dan kontraksi, misalnya `" I thought I 'd get her some with my dollar , "`, dan semua posisi di berkas label mengacu ke teks itu. Jalankan engine pada `514_little_women.txt`, bukan pada `BookContent`, lalu bandingkan per token. Kalau dijalankan pada EPUB, posisinya bergeser dan skornya salah.

**Pemetaan ke engine.**
- Hanya PER yang relevan untuk engine tokoh. FAC, GPE, LOC, VEH, dan ORG diabaikan.
- LitBank menandai nama (`Beth`) dan frasa umum (`her daughter`), sehingga bisa dibandingkan dengan mention nama dan deskripsi dari engine.
- Kata ganti (`he`, `her`) hanya ada di `coref.conll`. Buang dari perbandingan, kecuali engine ikut menandainya.
- Kelompok di `coref.conll` setara dengan satu tokoh di pemberhentian 6. Satu kelompok bisa memuat beberapa nama, dan satu tokoh engine bisa terpecah ke beberapa kelompok. Hitung keduanya sebagai kesalahan.

**Status.** Belum ada kode yang membaca berkas ini dan belum ada skor. Berkasnya ikut masuk ke bundel aplikasi (±164 KB). Semua berkas dipisah dengan nama unik karena XcodeGen meratakan nama berkas resource.

---

## Titik awal tuning

Semua yang di bawah terlihat di contoh 3 halaman ini. Untuk mengukur terhadap label manusia, lihat bagian "Data pembanding: LitBank".

| Masalah | Terjadi di | Knob atau tempat yang terkait |
|---|---|---|
| s144 (Amy) jadi Beth karena satu kata "hair" | Pemberhentian 7, skor tepat di ambang | `MentionLinkerKnobs.strongMatchTotal`, `strongMatchModifiers`, `sharedModifierScore` |
| Deskripsi s141 tidak langsung ke Beth | Pemberhentian 7, pola apositif terlalu sempit | `MentionLinkerKnobs.appositionConnectors` |
| Daftar isi dianggap cerita: Beth "pertama muncul" di s20, kutipan dan `summary` jadi judul bab | Pemberhentian 3 (isi `BookContent`), 6, dan 9 | Belum ada knob; perlu aturan untuk melewati daftar isi |
| "brown" jadi tokoh "Brown" | Pemberhentian 4 (NLTagger) dan 5 | `MentionFinderKnobs`, misalnya menolak nama berhuruf kecil |
| **Bug spoiler:** s115 "a little girl" → Jenny Snow, yang baru muncul di s1504 | Pemberhentian 8, `merge` mengikuti penggabungan yang terjadi sesudah kalimatnya | `ResolvedAnalysis.merge(_:into:at:decidedBy:)`; ini perbaikan kode, bukan tuning |
| Gabung nama tidak menghasilkan apa pun (0 nama) | Pemberhentian 8, kalimat yang dikirim adalah kalimat pertama tiap nama, yang jarang memuat dua nama sekaligus | `TieBreakSvc.groupNames`, `LLMKnobs.maxNamesPerCall` |
| Hanya 150 dari 405 *undecided* yang ditanyakan ke model | Pemberhentian 8 | `LLMKnobs.maxCallsPerRun` |
| Semua simbol bergeser saat fase 2 selesai | Pemberhentian 9, simbol dibagikan menurut urutan | `AnalysisMapper.map`, `AnalysisMapperKnobs.minimumMentions` |
| Simbol Father dan Mother bisa tertukar antar peluncuran | Pemberhentian 9, keduanya muncul di kalimat yang sama dan urutannya acak | `AnalysisMapper.map` (perlu pemecah seri) |
| "eyed" tidak dianggap sama dengan "eye" | Pemberhentian 7 | `MentionLinkerKnobs.minLengthToStripEd`, `MentionLinker.comparable` |

Aplikasi belum punya cara melihat angka-angka ini. Semua data di dokumen ini diambil dengan skrip kecil yang menjalankan `AnalysisScheduleSvc` di Mac, di luar repo. Setelah mengubah knob, cara paling cepat melihat efeknya adalah membandingkan jumlah tokoh, mention, dan garis bawah di pemberhentian 9.
