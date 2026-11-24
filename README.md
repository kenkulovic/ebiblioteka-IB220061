# eBiblioteka

Sistem gradske biblioteke: katalog knjiga, rezervacije, posudbe, zakasnine s online plaćanjem (PayPal),
obavijesti i preporuke knjiga.

Seminarski rad iz predmeta **Razvoj softvera II**, FIT Mostar, 2025/26.
Autor: Kenan Kulović, IB220061.

| Dio | Opis |
|---|---|
| `src/eBiblioteka.Api` | REST API (.NET 10, ASP.NET Core, EF Core, JWT) |
| `src/eBiblioteka.Worker` | Servis koji čita RabbitMQ i šalje e-mailove (mikroservis) |
| `src/eBiblioteka.Shared` | Zajedničke poruke i postavke API-ja i Workera |
| `desktop/` | Flutter desktop aplikacija za bibliotekare (Windows) |
| `mobile/` | Flutter mobilna aplikacija za članove (Android) |
| `common/ebiblioteka_api` | Dart paket s modelima i API klijentom koji dijele obje aplikacije |
| `recommender-dokumentacija.md` | Opis sistema preporuke |

## Šta je potrebno

- Docker Desktop
- Flutter (testirano s 3.50.1) i Android Studio s emulatorom za mobilnu aplikaciju
- Visual Studio 2022/2026 (radni teret "Desktop development with C++") za izgradnju Windows aplikacije
- .NET SDK 10 (samo ako se API pokreće izvan Dockera)

## Pokretanje

### 1. Postavke (`.env`)

Sve postavke (baza, RabbitMQ, SMTP, JWT, PayPal) su na jednom mjestu, u `.env` u korijenu projekta.
Kopirajte šablon i po potrebi promijenite vrijednosti:

```powershell
Copy-Item .env.example .env
```

`CORS_ORIGINS` je popis dozvoljenih origina (odvojenih zarezom) koji smiju zvati API iz preglednika; CORS je
definisan na jednom mjestu (`Program.cs`) i ne dozvoljava nijedan drugi origin. Desktop i mobilna aplikacija nisu
preglednik, pa na njih ne utiče.

Pri predaji se `.env` isporučuje u zaštićenom arhivu `.env-tajne.zip` (lozinka je u opisu predaje).
Raspakujte ga u korijen projekta.

### 2. Backend (baza, RabbitMQ, SMTP, API, Worker)

```powershell
docker compose up -d --build
```

Pri prvom pokretanju API sam kreira bazu `220061`, primjenjuje migracije i ubacuje početne podatke
(knjige sa slikama, članove, posudbe, rezervacije, zakasnine, vijesti).

| Servis | Adresa |
|---|---|
| API | http://localhost:5028 (OpenAPI opis: `/openapi/v1.json`) |
| Mailpit (primljeni e-mailovi) | http://localhost:8025 |
| RabbitMQ upravljanje | http://localhost:15672 (korisnik i lozinka iz `.env`) |
| SQL Server | `localhost,14333` (korisnik `sa`, lozinka iz `.env`) |

Zaustavljanje: `docker compose down` (podaci ostaju u Docker volumenima).

### 3. Desktop aplikacija (bibliotekari)

Adresa API-ja se zadaje preko `--dart-define` (nije upisana u kodu):

```powershell
cd desktop
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5028
```

### 4. Mobilna aplikacija (članovi)

Iz Android emulatora računar se vidi kao `10.0.2.2`:

```powershell
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5028
```

Za fizički uređaj u istoj mreži koristite IP adresu računara, npr. `http://192.168.1.10:5028`.

## Korisnici za testiranje

Lozinka za sve račune je **`test`**.

| Aplikacija | Korisničko ime | Uloga | Napomena |
|---|---|---|---|
| Desktop | `desktop` | Administrator | bibliotekar |
| Mobilna | `mobile` | Member | čist račun: rezervacije, posudbe, ocjene, preporuke |
| Mobilna | `maja` | Member | ima neplaćenu zakasninu: služi za probu plaćanja putem PayPal-a |
| Mobilna | `adnan` | Member | ima posudbu kojoj je istekao rok (kasni) |
| Mobilna | `amra` | Member | ima potvrđenu rezervaciju i obavijest |
| Mobilna | `emir`, `tarik`, `sara` | Member | historija posudbi i ocjena |

Novi član se može registrovati u mobilnoj aplikaciji.

## PayPal (sandbox)

Plaćanje zakasnine koristi **stvarnu integraciju s PayPal sandbox API-jem** (Orders v2: kreiranje narudžbe,
odobrenje u aplikaciji, potvrda na serveru, povrat uplate). Za rad su potrebni sandbox ključevi:

1. Na https://developer.paypal.com otvorite **Apps & Credentials**, odaberite **Sandbox** i napravite aplikaciju.
2. Kopirajte **Client ID** i **Secret** u `.env`:
   ```
   PAYPAL_CLIENT_ID=...
   PAYPAL_CLIENT_SECRET=...
   ```
3. Ponovo pokrenite API: `docker compose up -d api`.
4. U mobilnoj aplikaciji (korisnik `maja`) otvorite **Moje knjige → Zakasnine → Plati putem PayPal-a**
   i prijavite se sandbox kupcem (račun tipa *Personal* u **Sandbox → Accounts**).

Bez ključeva API radi, a pokušaj plaćanja vraća poruku da usluga plaćanja nije dostupna.

Pravila plaćanja: iznos određuje server; naplata je u EUR po fiksnom kursu 1 EUR = 1,95583 KM (PayPal ne podržava
konvertibilnu marku); uplatu potvrđuje server (capture), a potvrda je idempotentna; zakasnina s otvorenom ili završenom
uplatom ne može se platiti ponovo. Bibliotekar može vratiti uplatu izvršenu putem PayPal-a (desktop: **Zakasnine → Uplate →
Vrati uplatu**), uz razlog od najmanje 10 znakova; vraća se iznos koji je PayPal stvarno naplatio.

## E-mailovi

API stavlja e-mail u RabbitMQ red, a Worker ga stvarno šalje SMTP serverom. U razvoju je to Mailpit, pa se svi
poslani e-mailovi vide na http://localhost:8025 (dobrodošlica pri registraciji, podsjetnik dan prije isteka roka
povrata, obavijest o zakasnini, uplati, povratu i potvrdi rezervacije, kod za reset lozinke).

Ako slanje ne uspije, Worker ponavlja pokušaj s eksponencijalnim razmakom (2 s, 4 s, ...), a poruka koja ne uspije ni
nakon tri pokušaja ide u red `ebiblioteka.email.dead` radi ručnog pregleda. Podsjetnik o roku povrata šalje pozadinski
posao API-ja (svaki sat; jednom po roku, a produženje roka traži novi podsjetnik).

## Testovi

| Šta | Komanda |
|---|---|
| Dart paket (jedinični) | `cd common/ebiblioteka_api; dart test test/api_client_test.dart` |
| Dart paket (protiv živog API-ja) | `$env:API_BASE_URL="http://localhost:5028"; dart test test/live_contract_test.dart` |
| Desktop aplikacija (Windows) | `cd desktop; flutter test integration_test/app_test.dart -d windows --dart-define=API_BASE_URL=http://localhost:5028` |
| Mobilna aplikacija (emulator) | `powershell -File scripts\run-mobile-tests.ps1` (sama priprema okruženje, vidi skriptu) |

Skripta za mobilnu aplikaciju pokreće i lažni PayPal server (`scripts/fake_paypal.py`) kako bi se tok plaćanja
mogao isprobati bez pravih ključeva; pravi PayPal se koristi samo uz ključeve iz `.env`.

## Arhitektura

- **API**: kontroler → servis → `DbContext`; kontroleri ne sadrže poslovnu logiku, koriste se DTO-ovi (ne entiteti),
  prilagođeni izuzeci i middleware pretvaraju greške u 400/401/403/404/409 s porukom, servisi su Scoped, sve metode su
  `async`, vrijeme je UTC, lista ima straničenje (najviše 50), upiti ne prave N+1.
- **Baza**: SQL Server, Code First migracije, 16 vlastitih tabela uz Identity; strani ključevi s `Restrict` (brisanje
  korištenog zapisa vraća poruku s razlogom), filtrirani jedinstveni indeksi za pravila (jedna otvorena rezervacija,
  jedna aktivna posudba, jedna otvorena uplata po zakasnini).
- **Sigurnost**: JWT (svaki token ima `jti`), `[Authorize(Roles = ...)]`, Id korisnika se uvijek čita iz tokena.
  Odjava (`POST /api/auth/logout`) poništava token na serveru (tabela `RevokedTokens`), pa se on više ne prihvata ni
  prije isteka; obje aplikacije pozivaju taj endpoint pri odjavi. Slike (naslovnica, vijest, profil) se primaju samo
  kao PNG ili JPEG: provjerava se MIME tip zahtjeva i stvarni sadržaj (prvi bajtovi), a ne naziv fajla.
- **Izvještaji**: dva PDF izvještaja (posudbe: period i neobavezno kategorija, 10 najposuđivanijih knjiga s prosječnom
  ocjenom; zakasnine: period i neobavezno status, članovi sa zakasninama, naplaćeno po načinu plaćanja, povrati i
  prosječno kašnjenje u danima).
- **Rezervacije**: stanja Na čekanju → Potvrđena → Završena/Otkazana, uz historiju promjena (ko, kada, razlog; promjene
  koje radi sistem bilježe se kao "Sistem"). Rok preuzimanja (3 dana) provjerava pozadinski posao.
- **Preporuke**: item-based collaborative filtering, objašnjivo; vidi `recommender-dokumentacija.md`.

## Predaja (GitHub Release)

Izdanje za predaju (APK i Windows Release folder u jednom ZIP-u, te `.env-tajne.zip` umjesto `.env`) pravi jedna skripta:

```powershell
powershell -File scripts\make-release.ps1 -SecretsPassword "<lozinka>"
```

Rezultat je `release\eBiblioteka-IB220061-v1.0.0.zip` (ide kao dodatak GitHub Release-a) i `.env-tajne.zip` u korijenu
repozitorija (zaštićen lozinkom, AES-256; lozinka se navodi u opisu predaje, nikad u repozitoriju).
Ako se u `.env` upišu pravi PayPal ključevi, skriptu treba ponovo pokrenuti da arhiva sadrži ažurirane postavke.

Release se objavljuje kao neizmjenjiv (*immutable*) na GitHub-u, s oznakom (tagom) koja se navodi u predaji, npr. `v1.0.0`.

APK je potpisan razvojnim ključem (dovoljno za instalaciju na emulator i uređaj za testiranje).
Aplikacije imaju adresu API-ja upisanu pri izgradnji: Windows `http://localhost:5028`, Android `http://10.0.2.2:5028`
(emulator); za drugu adresu skripta prima parametre `-WindowsApiUrl` i `-AndroidApiUrl`.

## Napomene

- Mobilna aplikacija dozvoljava nešifrovan HTTP saobraćaj jer API u razvoju radi na `http` adresi u lokalnoj mreži.
  U stvarnom okruženju API bi bio iza HTTPS-a.
- Blokiranom članu prijava je zabranjena, a već izdati token se odbija odmah (provjera pri svakom zahtjevu: token nije
  poništen odjavom i račun nije blokiran); rezervacija i posudba su dodatno blokirani provjerom na serveru.
- Font za PDF izvještaje (DejaVu Sans) isporučuje se uz API (`src/eBiblioteka.Api/Resources/Fonts`, licenca u istom folderu).
  PDF se pravi bibliotekom QuestPDF (Community licenca, besplatna za nekomercijalnu i akademsku upotrebu).
