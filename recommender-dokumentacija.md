# Sistem preporuke – dokumentacija

eBiblioteka preporučuje knjige članovima algoritmom **item-based collaborative filtering** s **prilagođenom kosinusnom
sličnošću** (*adjusted cosine similarity*), onako kako je opisano u odobrenoj prijavi teme (poglavlje 6). Model uči iz
stvarnih ocjena koje članovi upisuju u mobilnoj aplikaciji nakon povrata knjige. Preporuke su objašnjive: uz svaku
stoji knjiga koja je najviše doprinijela predviđanju i vrijednost sličnosti.

Kod: `src/eBiblioteka.Api/Services/Recommender/` (parametri i izračun sličnosti),
`src/eBiblioteka.Api/Services/RecommendationService.cs` (predviđanje i preporuke),
`src/eBiblioteka.Api/BackgroundJobs/SimilarityRecalculationJob.cs` (preračunavanje).

## 1. Ulazni podaci

Samo ocjene (1–5) koje članovi upisuju nakon povrata knjige (jedna ocjena po posudbi; moguće je i naknadno izmijeniti).
Ako je član više puta posuđivao i ocjenjivao istu knjigu, uzima se prosjek njegovih ocjena te knjige.
Za *hladni start* (popularne knjige) koristi se evidencija posudbi.

## 2. Sličnost dvije knjige (prilagođeni kosinus)

Od svake ocjene se oduzme prosječna ocjena tog člana (blagi i strogi ocjenjivači postaju uporedivi), a zatim se
sličnost knjiga A i B računa nad članovima koji su ocijenili **obje** knjige:

```
                       Σ_u (r(u,A) − prosjek(u)) · (r(u,B) − prosjek(u))
sličnost(A, B) = ───────────────────────────────────────────────────────────────
                  √Σ_u (r(u,A) − prosjek(u))²  ·  √Σ_u (r(u,B) − prosjek(u))²
```

- `prosjek(u)` je prosjek svih ocjena člana `u`;
- parovi s **manje od 2 zajednička člana** se ne uzimaju u obzir (jedan član je slučajnost);
- pamte se samo **pozitivne** sličnosti (za predviđanje se koriste samo one); sličnost je simetrična, pa se pamti u oba smjera
  u tabeli `BookSimilarities`.

### Primjer s pravim podacima: Prokleta avlija – Tvrđava

Članovi koji su ocijenili obje knjige:

| Član | Prokleta avlija | Tvrđava | Prosjek svih ocjena člana | Prokleta avlija − prosjek | Tvrđava − prosjek |
|---|---|---|---|---|---|
| Adnan | 4 | 5 | 3,5 | +0,5 | +1,5 |
| Tarik | 2 | 2 | 3,6 | −1,6 | −1,6 |

```
brojnik     = 0,5·1,5 + (−1,6)·(−1,6)           = 0,75 + 2,56 = 3,31
|Prokleta|  = √(0,5² + 1,6²) = √2,81 = 1,6763
|Tvrđava|   = √(1,5² + 1,6²) = √4,81 = 2,1932
sličnost    = 3,31 / (1,6763 · 2,1932)            = 0,9003
```

Isti rezultat je u bazi (`BookSimilarities`: 0,9003, zajedničkih članova: 2).

## 3. Predviđanje ocjene

Za knjigu K koju član **nije posuđivao**:

1. uzme se do **10 najsličnijih knjiga koje je član ocijenio** (samo pozitivne sličnosti);
2. predviđena ocjena je **ponderisani prosjek** članovih ocjena tih knjiga, a težina je sličnost:

```
predviđena ocjena(K) = Σ sličnost(K, B) · ocjena člana za B  /  Σ sličnost(K, B)
```

### Primjer: preporuka „Tvrđava“ za Lejlu

Lejla je ocijenila: Na Drini ćuprija 5, Prokleta avlija 5, Derviš i smrt 4, 1984 2. Tvrđava je slična knjigama
Derviš i smrt (sličnost 1,00) i Prokleta avlija (0,90); sa ostalim Lejlinim knjigama nema pozitivnu sličnost.

```
predviđena ocjena(Tvrđava) = (1,00·4 + 0,9003·5) / (1,00 + 0,9003) = 8,5015 / 1,9003 = 4,47
```

Najviše je doprinijela knjiga s najvećim proizvodom sličnosti i ocjene: Prokleta avlija (0,9003·5 = 4,50 naspram 1,00·4 = 4,00).

## 4. Rezultat

Do **5 knjiga** s najvišom predviđenom ocjenom, uz uslov da je predviđena ocjena **najmanje 3,5**. Isključuju se knjige koje je
član već posuđivao. Dostupnost knjige prikazuje se u detaljima knjige.

**Objašnjenje** uz svaku preporuku (polje `Explanation`), npr.:

> Zato što ste visoko ocijenili ‚Prokleta avlija‘ (sličnost 0,90)

Za knjigu koju je član ocijenio niže od 4 tekst glasi „Zato što ste ocijenili ‚…‘ ocjenom 3 (sličnost …)“.
Uz tekst API vraća i strukturirane podatke (knjiga, sličnost, broj zajedničkih članova, članova ocjena).

## 5. Nedovoljno podataka (hladni start)

Član s **manje od 3 ocjene**, ili član za kojeg nijedna knjiga nema predviđenu ocjenu od najmanje 3,5, dobija **popularne
knjige**: one s najviše posudbi u posljednjih 30 dana (isključujući već posuđene), uz objašnjenje
„Najčešće posuđivano ovog mjeseca.“ (`Source = Popular`).

## 6. Kada se model preračunava

Tabela `BookSimilarities` se preračunava:

- **nakon svake nove ili izmijenjene ocjene** (servis ocjena javlja pozadinskom poslu, koji kratko sačeka da spoji više
  ocjena u nizu pa preračuna jednom);
- pri pokretanju aplikacije i povremeno (svakih 6 sati);
- na zahtjev administratora: `POST /api/recommendations/recalculate`.

Brisanje stare i upis nove tabele su jedna transakcija, pa čitaoci nikad ne vide praznu tabelu.

## 7. API

| Endpoint | Ko | Opis |
|---|---|---|
| `GET /api/recommendations?count=5` | član | personalizovane (ili popularne) preporuke s objašnjenjem, najviše 5 |
| `GET /api/books/{id}/similar?count=5` | prijavljeni | slične knjige (za detalje knjige) |
| `POST /api/recommendations/recalculate` | administrator | ručno preračunavanje; vraća broj upisanih zapisa |

## 8. Parametri (`RecommenderSettings.cs`)

| Parametar | Vrijednost |
|---|---|
| najmanje zajedničkih članova za par knjiga | 2 |
| broj najsličnijih knjiga u predviđanju | 10 |
| najmanja predviđena ocjena za preporuku | 3,5 |
| najmanje ocjena člana za personalizovane preporuke | 3 |
| razdoblje za popularne knjige | 30 dana |
| najviše preporuka | 5 |

## 9. Ograničenja

- Radi dobro tek kad ima dovoljno ocjena različitih članova; na malom skupu podataka malo je parova s dovoljno
  zajedničkih članova.
- Ne koristi sadržaj knjige (žanr, autora), samo ponašanje članova. Nova knjiga bez ocjena se ne preporučuje dok je neko ne ocijeni.
- Računanje je u memoriji (složenost: broj parova knjiga × broj članova), što je za biblioteku zanemarivo.

## 10. Kako provjeriti

Početni podaci imaju 7 članova s 38 ocjena u dvije grupe ukusa (klasici i distopija/nauka), pa preporuke rade odmah.

1. Prijava kao `mobile` / `test` (Lejla): `GET /api/recommendations` vraća Travničku hroniku (5,00) i Tvrđavu (4,47) s objašnjenjem.
2. Novi član (registracija) ima manje od 3 ocjene pa dobija popularne knjige (`Source = Popular`).
3. Kad Lejla pročita i ocijeni knjigu, model se preračuna sam, a preporuke se mijenjaju.
4. Tačnost izračuna provjerena je neovisnom implementacijom (Python) nad istim podacima iz baze: svih 22 zapisa u tabeli
   `BookSimilarities` poklapa se u sličnosti i broju zajedničkih članova, a poklapaju se i predviđene ocjene za Lejlu.
