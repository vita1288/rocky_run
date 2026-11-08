# Rocky Run – Google Play listing

Copy these into Play Console → Grow → Store presence → Main store listing.

## App details
- **App name** (max 30): `Rocky Run`
- **Package name:** `com.jovita.rockyrun`
- **Category:** Game → Arcade
- **Tags:** Runner, Casual, Offline
- **Contact email:** jovitasutanto98@gmail.com
- **Privacy policy URL:** https://rockyrunwafel.netlify.app/privacy.html

## Short description (max 80)
EN: `Help Rocky the red toy poodle jump over rocks, grab bones and set a high score!`
ID: `Bantu Rocky si toy poodle merah lompati batu, ambil tulang, cetak skor tertinggi!`

## Full description (max 4000)
EN:
```
Meet Rocky, a fluffy red toy poodle who just loves to run!

Tap to jump over rocks, tap again in the air to double jump, and hold for an extra-high leap. Collect bones for bonus points, keep your 3 hearts safe, and see how far Rocky can go as the run gets faster and faster.

FEATURES
• Simple one-tap controls – easy to learn, hard to master
• Double jump and high jump for tricky rock combos
• 3 hearts per run, so one mistake isn't the end
• Collect bones for +25 points each
• Original chiptune music and sound effects
• Play in portrait or landscape
• English and Bahasa Indonesia
• Works offline – no ads, no accounts, no data collected

How far can Rocky run? Beat your best score!
```

ID:
```
Kenalan dengan Rocky, toy poodle merah berbulu lembut yang hobinya berlari!

Ketuk untuk melompati batu, ketuk lagi di udara untuk lompat ganda, dan tahan untuk lompatan ekstra tinggi. Kumpulkan tulang untuk poin bonus, jaga 3 nyawamu, dan lihat seberapa jauh Rocky bisa berlari saat larinya makin cepat.

FITUR
• Kontrol satu ketukan – mudah dipelajari, seru untuk dikuasai
• Lompat ganda dan lompat tinggi untuk kombinasi batu yang sulit
• 3 nyawa per permainan
• Kumpulkan tulang, +25 poin per tulang
• Musik dan efek suara chiptune orisinal
• Bisa dimainkan tegak maupun mendatar
• Bahasa Inggris dan Bahasa Indonesia
• Bisa offline – tanpa iklan, tanpa akun, tanpa pengumpulan data

Seberapa jauh Rocky bisa berlari? Kalahkan skor terbaikmu!
```

## Graphics checklist
| Asset | Size | Source |
| --- | --- | --- |
| App icon | 512 × 512 PNG | resize `assets/icon/rocky_icon_1024.png` |
| Feature graphic | 1024 × 500 PNG/JPG | to make (Rocky + title on sky background) |
| Phone screenshots | 2–8, 16:9 or 9:16, min 320 px | take from the release build on a phone |

## App content answers (Policy → App content)
- **Privacy policy:** URL above
- **Ads:** No, the app contains no ads
- **App access:** All functionality available without special access
- **Content rating:** questionnaire → Game; no violence beyond cartoon obstacles, no user interaction, no data sharing → expected rating: Everyone / 3+
- **Target audience:** 13–15, 16–17, 18+ (do NOT tick under-13 groups; that triggers the Families policy)
- **Data safety:** "No data collected" and "No data shared" (best score and settings stay on the device only)
- **Government app / Financial features / Health:** No

## Release steps
1. `powershell -ExecutionPolicy Bypass -File tools\create_upload_key.ps1` (once; back up the key + password)
2. Raise `version:` in pubspec.yaml for every upload (1.0.0+1 → 1.0.1+2 ...)
3. `flutter clean` → `flutter build appbundle --release`
4. Upload `build\app\outputs\bundle\release\app-release.aab` to **Testing → Closed testing**
5. Keep ≥12 testers opted in for 14 consecutive days → Dashboard → **Apply for production**
