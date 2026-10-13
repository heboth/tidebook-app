# Go Nordic Cruiseline • Tidebook Mobil App

Officiel passagerapp til **Go Nordic Cruiseline** (iOS og Android), bygget i Flutter.

Appen håndterer hele passagerrejsen mellem København og Oslo med færgerne **M/F Nordic Crown** og **M/F Nordic Pearl**: reservation, sikker betaling via Nets, rejseopslag, mobil check-in, kryptografisk signerede boardingkort og destinationsguider.

---

## 🛳️ Hovedfunktioner

1. **Book Overfart (Booking Wizard)**
   - Valg af rute (København ⇄ Oslo) og afgangsdato.
   - Kahytsvalg (Commodore Balcony, Commodore de Luxe, Standard m.fl.).
   - Måltider og tilkøb (Skandinavisk buffet, WiFi, VIP Lounge).
   - Indtastning af passager- og køretøjsoplysninger.

2. **Sikker Nets Betaling**
   - Samme betalingsflow som webløsningen: integreret mod Core's betalingsmotor (`/api/integrations/payments`).
   - Pladsen reserveres som `PENDING` i TideRMS under betaling.
   - Godkendelse via Nets Easy / Nets Simulator med serverbekræftelse (`complete`).
   - Udstedelse af kundens signerede booking-nøgle (`X-Booking-Token`) ved gennemført betaling.

3. **Mine Bookinger & Opslag**
   - Sikret opslag med bookingnummer (PNR) og e-mail eller efternavn mod Core (`/api/bookings/lookup`).
   - Henter og gemmer booking-nøglen (`X-Booking-Token`) lokalt til godkendelse af efterfølgende handlinger.
   - Adgangsbeskyttelse: afviser gruppereservationer (henvises til gruppeportalen) og agentbookinger (henvises til bureauet).

4. **Mobil Check-In & Boardingkort**
   - Mobil check-in åbner og lukker efter rederiets regler (lukker 15 min. før afgang mod Core's MNG-06 regel).
   - Sender `X-Booking-Token` i headeren for at beskytte mod uautoriseret check-in.
   - **Kryptografisk signerede boardingkort**: QR-koderne genereres og signeres af TideBook Core (`TB:<pnr>:<ticketId>:<hmac>`) og hentes direkte fra check-in-svaret.
   - Appen indeholder ingen statiske salte eller hemmeligheder i kildekoden.

5. **Passagerprofil & Portal Login**
   - Autentifikation mod TideBook Core's portal-login (`POST /api/auth/portal-login`).
   - Håndhævelse af roller: B2B Online Agenter (OA) og gruppeledere afvises automatisk med henvisning til deres dedikerede portaler.
   - Hurtig udfyldelse af stamdata (navn, e-mail, mobil, bilnummer) ved booking.

6. **Destinationsguide & Rejseinformation**
   - Oplevelses- og skiguide for Oslo, Norefjell, Hemsedal og Trysil samt København.
   - Terminaloplysninger (Dampfærgevej 30 i København og Revierkaia/Vippetangen i Oslo).

---

## 🔒 Sikkerhedsarkitektur

| Komponent | Implementering |
|---|---|
| **Betaling** | Går udelukkende gennem betalingsmotoren (`/api/integrations/payments`). Appen kan ikke selv erklære bookinger som `PAID`. |
| **Booking-adgang** | Kræver `X-Booking-Token` (30 dages HMAC/JWT udstedt af Core ved opslag/betaling). PNR alene giver ikke adgang til check-in eller persondata. |
| **Boardingkort** | Udstedes og HMAC-signeres af Core. Appen gemmer eller bruger intet statisk salt; QR-payload hentes fra Core's check-in svar. |
| **Manifest-beskyttelse** | Passagerlister og boardingdata (`/api/boarding/:departureId/manifest`) er beskyttet i Core og kræver medarbejder- eller intern token. |
| **Autentifikation** | Login verificeres mod Core's identity service (`/api/auth/portal-login`), og tokens fornys sikkert. |
| **API-konfiguration** | API-adressen er dynamisk konfigurerbar og ikke låst til hardkodet `localhost:4000`. |

---

## 🛠️ Teknologistak

- **Framework:** Flutter 3.x / Dart 3.x
- **Arkitektur:** Provider / ChangeNotifier (`BookingService`, `AuthService`, `ApiService`)
- **UI & Tema:** Skandinavisk maritimt design baseret på Go Nordic Cruiseline tokens (`pine`, `teal`, `lime`, `sand`)
- **Netværk:** HTTP klient med JSON serialisering og timeout-beskyttelse
- **QR:** `qr_flutter` til rendering af Core's officielle gate-strenge

---

## 🚀 Kom i gang

### Forudsætninger
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24+ anbefalet)
- Xcode (til iOS / macOS) eller Android Studio / SDK (til Android)
- TideBook Core backend kørende lokalt (port 4000)

### Installation
```bash
# Hent afhængigheder
flutter pub get
```

### Konfiguration af API-adresse
Som standard forbinder appen automatisk til:
- Android emulator: `http://10.0.2.2:4000/api`
- iOS simulator / desktop: `http://localhost:4000/api`

API-adressen kan overstyres under opstart:
```bash
# Kør med brugerdefineret backend-URL via dart-define
flutter run --dart-define=TIDEBOOK_API_URL=https://api.gonordic.dk/api
```

Eller programmatisk under runtime:
```dart
ApiService.setBaseUrl('https://api.gonordic.dk');
```

### Miljøvariabler

Tide-suiten deler én miljøfil: `.env` i mappen med alle repoerne (fx `/Volumes/T9/Development/.env`, oprettes med
`npm run env:init` i TideBook – alle variabler i `TideBook/config/tide.env.example`). Appen læser kun to adresser:

| Fælles navn | dart-define i appen |
|---|---|
| `TIDE_CORE_URL` | `TIDEBOOK_API_URL` (`/api` tilføjes automatisk) |
| `TIDE_CMS_URL` | `TIDECMS_URL` |

```bash
tool/run.sh                 # flutter run med adresserne fra den fælles fil
tool/run.sh build ios       # flutter build ios med de samme adresser
```

`tool/run.sh` læser kun de to nøgler – brug aldrig `--dart-define-from-file` med den fælles fil, for så bliver alle
dens hemmeligheder bygget ind i appen. localhost-adresser gives ikke videre (appens standarder klarer både
iOS-simulatoren og Android-emulatorens 10.0.2.2), og `TIDEBOOK_API_URL`/`TIDECMS_URL` sat i miljøet vinder.

### Kørsel
```bash
# Kør på tilsluttet enhed eller simulator
flutter run
```

---

## 🧪 Test & Kvalitetssikring

Kør hele testsuiten:
```bash
# Kør alle enheds- og widget-tests
flutter test

# Kør statisk analyse
flutter analyze
```

Testsuiten dækker bl.a.:
- Verifikation af Nets betalingsflow (start checkout, simulation, completion).
- Parsing af Core-udstedte boardingkort og ekstraktion af gate-HMAC.
- Håndtering af booking-nøgler (`X-Booking-Token`) ved opslag og check-in.
- Håndtering af fejlmeddelelser ved afvist check-in (fx 15 min. cutoff).
- Adgangskontrol ved portal-login (afvisning af OA-agenter og gruppeledere).
- Dynamisk konfiguration af `ApiService.baseUrl`.

---

## 📁 Projektstruktur

```
lib/
├── main.dart                      # App entry point
├── models/
│   ├── booking_model.dart         # BookingModel & BoardingPassModel
│   ├── departure_model.dart       # Afgange og fartplan
│   ├── passenger_model.dart       # Passagerer og køretøjer
│   ├── cabin_model.dart           # Kahytskategorier
│   ├── addon_model.dart           # Måltider og oplevelser
│   ├── route_model.dart           # Ruter (CPH-OSL)
│   └── user_model.dart            # Passagerprofil og roller
├── screens/
│   ├── home_screen.dart           # Hovednavigation og overblik
│   ├── booking_wizard_screen.dart # 5-trins bookingflow inkl. Nets betaling
│   ├── my_bookings_screen.dart    # Mine bookinger og opslag via PNR
│   ├── booking_detail_screen.dart # Bookingdetaljer og check-in
│   ├── boarding_pass_screen.dart  # Visning af Core's signerede boardingkort
│   ├── explore_screen.dart        # Færge- og oplevelsesoversigt
│   ├── destination_guide_screen.dart # Norgestur & rejseguide
│   ├── profile_screen.dart        # Passagerprofil
│   └── login_screen.dart          # Login mod Core portal-login
├── services/
│   ├── api_service.dart           # HTTP API klient (Core, Nets, auth)
│   ├── auth_service.dart          # Brugerautentifikation og session
│   ├── booking_service.dart       # Bookinghåndtering og nøglelager
│   ├── qr_security_service.dart   # Hjælpefunktioner til Core boardingkort
│   └── seed_data.dart             # Lokale fallback- og demodata
├── theme/
│   └── gonordic_theme.dart        # Go Nordic Cruiseline design tokens
└── widgets/
    ├── maritime_qr_widget.dart    # QR visning med SOLAS gate-kontrol
    ├── booking_card.dart          # Bookingkort i liste
    ├── cabin_card.dart            # Kahytskort i wizard
    └── gonordic_banner.dart       # Kampagne- og velkomstbannere
```

---

## 🚢 Rederi & Licens

Udviklet til **Go Nordic Cruiseline** • Driftet på [TideBook Core](https://codeberg.org/heboth/tidebook).  
Ophavsret © 2026 Go Nordic Cruiseline A/S. Alle rettigheder forbeholdes.

