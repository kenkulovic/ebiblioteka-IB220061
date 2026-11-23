# Sistem preporuke – dokumentacija

eBiblioteka preporučuje knjige članovima pomoću **item-based collaborative filtering** algoritma:
knjige su slične ako ih čitaju isti članovi. Algoritam je namjerno jednostavan i potpuno objašnjiv:
svaka preporuka dolazi s razlogom (koje je knjige član čitao i koliko su slične preporučenoj).

Kod: `src/eBiblioteka.Api/Services/Recommender/` (parametri i izračun sličnosti) i
`src/eBiblioteka.Api/Services/RecommendationService.cs` (preporuke za člana).

## 1. Podaci koji se koriste

Samo podaci koje biblioteka već ima, bez posebnog unosa:

| Izvor | Šta znači |
|---|---|
| Posudbe (`Loans`) | član je čitao knjigu (aktivna ili vraćena posudba) |
| Ocjene (`Reviews`) | koliko mu se knjiga svidjela (1–5) |

Za par (član, knjiga) postoji jedna **interakcija** s težinom `w` u rasponu (0, 1]:

- ako je član ocijenio knjigu: `w = ocjena / 5` (ocjena 5 → 1,0; ocjena 3 → 0,6; ocjena 1 → 0,2);
- ako je posudio, ali nije ocijenio: `w = 0,6` (neutralno, kao ocjena 3);
- ako je knjigu posuđivao više puta, uzima se prosjek njegovih ocjena.

Rezervacije se ne računaju (rezervacija je namjera, ne čitanje).

## 2. Sličnost dvije knjige

Svaka knjiga je vektor s po jednim elementom za svakog člana (težina interakcije ili 0).
Sličnost knjiga A i B je **kosinusna sličnost** tih vektora:

```
sličnost(A, B) =  Σ_člana  w(član, A) · w(član, B)
                 ───────────────────────────────────
                   √(Σ w(·, A)²)  ·  √(Σ w(·, B)²)
```

Rezultat je u rasponu [0, 1]: 1 znači da isti članovi daju istu težinu objema knjigama.
Brojnik sabira samo članove koji su čitali **obje** knjige; imenilac uzima sve čitaoce svake knjige,
pa knjiga koju čita puno ljudi ne postaje "slična svemu".

### Primjer s pravim podacima

Derviš i smrt – Tvrđava (iz početnih podataka):

| Član | Derviš i smrt | Tvrđava |
|---|---|---|
| Lejla | ocjena 4 → 0,8 | nije čitala |
| Maja | ocjena 5 → 1,0 | ocjena 4 → 0,8 |
| Adnan | ocjena 5 → 1,0 | ocjena 5 → 1,0 |
| Tarik | nije čitao | ocjena 3 → 0,6 |

```
brojnik   = 1,0·0,8 + 1,0·1,0                = 1,80   (samo Maja i Adnan su čitali obje)
|Derviš|²  = 0,8² + 1,0² + 1,0²              = 2,64
|Tvrđava|² = 0,8² + 1,0² + 0,6²              = 2,00
sličnost  = 1,80 / (√2,64 · √2,00) = 1,80 / 2,2978 = 0,7833
```

API vraća isto: `GET /api/books/{id}/similar` za "Derviš i smrt" daje Tvrđavu sa sličnošću 0,7833 i 2 zajednička čitaoca.

## 3. Parametri (`RecommenderSettings.cs`)

| Parametar | Vrijednost | Zašto |
|---|---|---|
| `MinCommonUsers` | 2 | par knjiga se povezuje tek ako ih je zajedno čitalo bar 2 člana; jedan član je slučajnost |
| `MinSimilarity` | 0,1 | slabije veze se ne pamte |
| `NeighborsPerBook` | 10 | za svaku knjigu pamti se 10 najsličnijih |
| težina bez ocjene | 0,6 | neutralna vrijednost |
| `RecalculateInterval` | 6 sati | koliko često se sličnost preračunava |

## 4. Preporuke za člana

1. Uzmu se knjige koje je član čitao (s težinama `w`).
2. Za svaku čitanu knjigu uzmu se njene najsličnije knjige iz tabele `BookSimilarities`.
3. Isključuju se knjige koje je član već posuđivao i one koje trenutno rezerviše.
4. Svaki kandidat dobija ocjenu:

```
ocjena(kandidat) = Σ  sličnost(čitana knjiga, kandidat) · w(čitana knjiga)
```

Zbir (a ne prosjek) je namjeran: kandidat koji je sličan s više članovih knjiga, i to onih koje je
visoko ocijenio, rangira se više. Knjiga slična jednoj omiljenoj i knjiga slična dvjema omiljenima
nisu jednako dobre preporuke.

5. Vraća se najviše `count` kandidata s najvećom ocjenom (zadano 5, najviše 20).

### Primjer: preporuka "Tvrđava" za Lejlu

Lejla je čitala: Na Drini ćuprija (1,0), Prokleta avlija (1,0), Derviš i smrt (0,8), 1984 (0,6), Životinjska farma (0,6).

```
Derviš i smrt → Tvrđava: sličnost 0,7833 · težina 0,8 = 0,6267
1984          → Tvrđava: sličnost 0,6042 · težina 0,6 = 0,3625
ocjena(Tvrđava) = 0,6267 + 0,3625 = 0,9892
```

## 5. Objašnjenje (explainability)

Svaka preporuka nosi razloge: do 3 knjige koje su najviše doprinijele ocjeni, svaka sa sličnošću i brojem
zajedničkih čitalaca. Server sastavlja i gotov tekst za prikaz:

> Preporučeno jer ste čitali: „Derviš i smrt” (sličnost 0,78, zajedničkih čitalaca: 2); „1984” (sličnost 0,60, zajedničkih čitalaca: 2).

Polje `Source` kaže kako je preporuka nastala: `Similar` (iz sličnosti) ili `Popular` (popuna, vidi dolje).

## 6. Novi članovi i premalo podataka (hladni start)

Član bez historije nema na osnovu čega dobiti personalizovane preporuke. Tada (i kad ima premalo sličnih
knjiga da se popuni tražen broj) preostala mjesta zauzimaju **najpopularnije knjige** (najviše posudbi,
pri izjednačenju bolja prosječna ocjena), uz objašnjenje "Popularno među članovima biblioteke (posudbi: N)".
Takve preporuke imaju `Source = Popular` i ocjenu 0.

## 7. Kada se računa

Tabela `BookSimilarities` se preračunava:

- pri pokretanju aplikacije i zatim svakih 6 sati (pozadinski posao `SimilarityRecalculationJob`);
- na zahtjev administratora: `POST /api/recommendations/recalculate`.

Preračunavanje briše staru tabelu i upisuje novu u **jednoj transakciji**, pa čitaoci nikad ne vide praznu tabelu.
Isključivanje već pročitanih knjiga radi odmah (provjerava se pri svakom zahtjevu), a sama sličnost se
osvježava pri sljedećem preračunavanju.

## 8. API

| Endpoint | Ko | Opis |
|---|---|---|
| `GET /api/recommendations?count=5` | član | personalizovane preporuke s objašnjenjem |
| `GET /api/books/{id}/similar?count=5` | prijavljeni | slične knjige (za ekran detalja knjige) |
| `POST /api/recommendations/recalculate` | administrator | ručno preračunavanje; vraća broj upisanih parova |

## 9. Ograničenja

- Radi dobro tek kad ima dovoljno posudbi i članova; na malom skupu podataka sličnosti su grube.
- Ne koristi sadržaj knjige (žanr, autora), samo ponašanje članova. Nova knjiga bez posudbi se ne preporučuje
  dok je neko ne pročita (poznati problem hladnog starta za stavke).
- Računanje je u memoriji: složenost je zbir kvadrata broja knjiga po članu, što je za biblioteku
  (nekoliko desetina knjiga po članu) zanemarivo. Za milione interakcija bi trebalo preći na paketnu obradu.
- Težina "bez ocjene = 0,6" je pretpostavka; ona se može promijeniti na jednom mjestu (`RecommenderSettings`).

## 10. Kako provjeriti

Početni podaci imaju 7 članova s historijom posudbi i ocjena, pa preporuke rade odmah.

1. Prijava kao `mobile` / `test` (Lejla), zatim `GET /api/recommendations`: dobija Tvrđavu, Kratku historiju vremena, Travničku hroniku...
   svaku s objašnjenjem.
2. Novi član (registracija) dobija popularne knjige (`Source = Popular`).
3. Nakon što Lejla pročita preporučenu knjigu, ona nestaje iz njenih preporuka, a nakon
   preračunavanja se mijenja i sličnost.
4. Tačnost izračuna je provjerena neovisnom implementacijom (Python) nad istim podacima iz baze:
   svih 38 parova u tabeli `BookSimilarities` poklapa se u sličnosti i broju zajedničkih čitalaca.
