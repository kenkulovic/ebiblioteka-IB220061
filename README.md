# **eBiblioteka - Library Management System**

eBiblioteka is a city library system: members browse the catalogue, reserve and borrow books, get recommendations and pay late fines online through PayPal. Librarians manage everything from a desktop app. The system is built with a .NET Web API, a RabbitMQ e-mail worker, and Flutter desktop and mobile applications.

Course project for **Razvoj softvera II**, FIT Mostar, 2025/26. Author: Kenan Kulović (IB220061).

---

## **How to Run the Project**

### **Environment Setup**

1. **Extract `.env-tajne.zip`**

   - Extract the file `.env-tajne.zip` (the password is given in the submission on DLWMS)
   - Put the resulting `.env` file into the root folder (the same directory where `docker-compose.yml` is located)

2. **Start Backend Services**

   - Run Docker and:

   ```bash
   docker compose up --build
   ```

   On the first start the API creates the database `220061`, applies the migrations and seeds the demo data.

3. **Locate the Desktop and Mobile Applications**

   - Download `fit-build-<date>.zip` from the GitHub Release of this repository and extract it
   - The Android app is `mobile\build\app\outputs\flutter-apk\app-release.apk`
   - The Windows app is `desktop\build\windows\x64\runner\Release\ebiblioteka_desktop.exe`

---

## **Installing the Applications**

- **Desktop Application**: Run `ebiblioteka_desktop.exe` (it talks to the API at `http://localhost:5028`)
- **Mobile Application**: Install `app-release.apk` on an Android emulator (it talks to the API at `http://10.0.2.2:5028`)

| Service | Address |
|---|---|
| API | http://localhost:5028 (OpenAPI: `/openapi/v1.json`) |
| Mailpit (received e-mails) | http://localhost:8025 |
| RabbitMQ management | http://localhost:15672 (credentials in `.env`) |
| SQL Server | `localhost,14333` (user `sa`, password in `.env`) |

---

## **Login Credentials**

The password for every account is **test**.

### **Desktop Application (Administrator)**

- **Username:** desktop
- **Password:** test

### **Mobile Application (Members)**

- **Username:** mobile (clean account: reservations, loans, ratings, recommendations)
- **Username:** maja (has an unpaid late fine, use it to test the PayPal payment)
- **Username:** adnan (has an overdue loan)
- **Username:** amra (has a confirmed reservation and a notification)

The desktop app rejects accounts that are not administrators and the mobile app rejects accounts that are not members. Access is also restricted on the server with role-based authorization. A new member can register in the mobile app.

---

## **Test Payment Credentials**

### **PayPal Sandbox**

Late fines are paid through the real PayPal sandbox (Orders v2: create order, approve, capture on the server, refund).

1. In the mobile app log in as `maja`, then open **Moje knjige → Zakasnine → Plati putem PayPal-a**
2. On the PayPal page log in with the sandbox buyer account:
   - **E-mail:** sb-ueyvw54113167@personal.example.com
   - **Password:** given in the submission on DLWMS
3. A librarian can refund the payment in the desktop app: **Zakasnine → Uplate → Vrati uplatu** (a reason of at least 10 characters is required)

The amount is set by the server and charged in EUR at a fixed rate of 1 EUR = 1.95583 KM, because PayPal does not support the convertible mark.

---

## **RabbitMQ**

The API puts e-mails on a RabbitMQ queue and the Worker sends them, so the API is never blocked by the mail server.

- **ebiblioteka.email** - e-mails to send (welcome, due-date reminder, fine, payment, refund, reservation confirmation, password reset code)
- **ebiblioteka.email.dead** - messages that failed after three attempts, kept for manual review

If sending fails, the Worker retries with an exponential delay (2 s, 4 s, ...). In development the mail server is Mailpit, so every sent e-mail can be seen at http://localhost:8025.

---

## **Project Structure**

| Folder | Description |
|---|---|
| `src/eBiblioteka.Api` | REST API (.NET 10, ASP.NET Core, EF Core, JWT) |
| `src/eBiblioteka.Worker` | RabbitMQ consumer that sends e-mails (microservice) |
| `src/eBiblioteka.Shared` | Messages and settings shared by the API and the Worker |
| `desktop/` | Flutter desktop application for librarians (Windows) |
| `mobile/` | Flutter mobile application for members (Android) |
| `common/ebiblioteka_api` | Dart package with models and the API client used by both apps |
| `recommender-dokumentacija.md` | Description of the recommendation system |

Recommendations use item-based collaborative filtering (adjusted cosine similarity), recalculated by a background job.

---

## **Running from Source (optional)**

Requirements: Docker Desktop, Flutter, Android Studio with an emulator, Visual Studio with the "Desktop development with C++" workload.

```powershell
docker compose up -d --build

cd desktop
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5028

cd ../mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5028
```

Tests:

| What | Command |
|---|---|
| Dart package (unit) | `cd common/ebiblioteka_api; dart test test/api_client_test.dart` |
| Dart package (live API) | `$env:API_BASE_URL="http://localhost:5028"; dart test test/live_contract_test.dart` |
| Desktop app | `cd desktop; flutter test integration_test/app_test.dart -d windows --dart-define=API_BASE_URL=http://localhost:5028` |
| Mobile app (emulator) | `powershell -File scripts\run-mobile-tests.ps1` (uses a fake PayPal server, `scripts/fake_paypal.py`) |

The release ZIP is built with `powershell -File scripts\make-release.ps1 -SecretsPassword "<password>"`.
