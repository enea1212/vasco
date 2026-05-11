# Plan de Refactorizare — Vasco Flutter App

> **Obiective**: Arhitectură Clean pe layere, SRP strict, componente reutilizabile,
> fișiere ≤ 300 linii, providere organizate pe responsabilități.
>
> **Mod de execuție**: Fiecare fază se execută cu **sub-agenți separați** care rulează
> în paralel pe task-uri independente. Agenții sunt long-running și primesc context complet
> (fișierul pe care îl rescriu + contractul de interfață cu restul sistemului).

---

## Structura țintă a directoarelor

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart           # paleta de culori
│   │   ├── app_text_styles.dart      # stiluri tipografice
│   │   └── app_sizes.dart            # spacing & radius
│   ├── errors/
│   │   └── app_exception.dart        # ierarhie excepții custom
│   ├── extensions/
│   │   ├── context_extensions.dart   # BuildContext helpers
│   │   └── string_extensions.dart
│   └── utils/
│       ├── scroll_utils.dart         # (mutat din utils/)
│       └── date_utils.dart
│
├── data/
│   ├── datasources/
│   │   ├── remote/
│   │   │   ├── user_remote_datasource.dart
│   │   │   ├── post_remote_datasource.dart
│   │   │   ├── friend_remote_datasource.dart
│   │   │   ├── message_remote_datasource.dart
│   │   │   ├── location_remote_datasource.dart
│   │   │   └── swipe_remote_datasource.dart
│   │   └── local/
│   │       ├── feed_local_datasource.dart    # Hive cache (din feed_cache_service)
│   │       └── photo_local_datasource.dart   # cache poze
│   ├── models/                       # JSON ↔ Firestore, extends domain entity
│   │   ├── user_model.dart
│   │   ├── post_model.dart
│   │   ├── friend_request_model.dart
│   │   ├── message_model.dart
│   │   └── swipe_model.dart
│   └── repositories/                 # implementări concrete
│       ├── user_repository_impl.dart
│       ├── post_repository_impl.dart
│       ├── friend_repository_impl.dart
│       ├── message_repository_impl.dart
│       ├── location_repository_impl.dart
│       └── swipe_repository_impl.dart
│
├── domain/
│   ├── entities/                     # obiecte pure, fără dependență Firebase
│   │   ├── user_entity.dart
│   │   ├── post_entity.dart
│   │   ├── friend_request_entity.dart
│   │   ├── message_entity.dart
│   │   ├── friend_location_entity.dart
│   │   └── match_entity.dart
│   ├── repositories/                 # contracte abstracte (interfaces)
│   │   ├── i_user_repository.dart
│   │   ├── i_post_repository.dart
│   │   ├── i_friend_repository.dart
│   │   ├── i_message_repository.dart
│   │   ├── i_location_repository.dart
│   │   └── i_swipe_repository.dart
│   └── usecases/
│       ├── auth/
│       │   ├── sign_in_usecase.dart
│       │   ├── sign_out_usecase.dart
│       │   └── register_usecase.dart
│       ├── profile/
│       │   ├── get_user_usecase.dart
│       │   └── update_profile_usecase.dart
│       ├── feed/
│       │   ├── get_feed_usecase.dart
│       │   └── toggle_like_usecase.dart
│       ├── friends/
│       │   ├── send_friend_request_usecase.dart
│       │   ├── accept_friend_request_usecase.dart
│       │   └── get_friends_usecase.dart
│       ├── location/
│       │   ├── publish_location_usecase.dart
│       │   ├── watch_friend_locations_usecase.dart
│       │   └── set_location_visibility_usecase.dart
│       └── swipe/
│           ├── get_candidates_usecase.dart
│           └── swipe_usecase.dart
│
├── presentation/
│   ├── providers/
│   │   ├── infrastructure/           # Layer 1 — fără UI state
│   │   │   ├── auth_state_provider.dart      # cine e logat
│   │   │   └── connectivity_provider.dart
│   │   ├── domain/                   # Layer 2 — wrapperi use-case
│   │   │   ├── user_provider.dart
│   │   │   ├── friends_provider.dart
│   │   │   ├── feed_provider.dart
│   │   │   ├── location_provider.dart        # înlocuiește friend_location_provider
│   │   │   ├── messaging_provider.dart
│   │   │   └── swipe_provider.dart
│   │   └── ui/                       # Layer 3 — state local de UI
│   │       ├── profile_ui_provider.dart
│   │       ├── map_ui_provider.dart
│   │       └── chat_ui_provider.dart
│   │
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── auth_layout.dart
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── home/
│   │   │   ├── home_screen.dart      # shell cu bottom nav
│   │   │   └── widgets/
│   │   │       ├── post_card.dart
│   │   │       └── story_row.dart
│   │   ├── feed/
│   │   │   ├── feed_page.dart
│   │   │   └── widgets/
│   │   │       └── feed_list.dart
│   │   ├── profile/
│   │   │   ├── profile_page.dart
│   │   │   ├── user_profile_screen.dart
│   │   │   ├── edit_profile_screen.dart  # mutat din repository/
│   │   │   ├── settings_page.dart
│   │   │   └── widgets/
│   │   │       ├── profile_header.dart       # extras din profile_page
│   │   │       ├── profile_stats_grid.dart
│   │   │       ├── profile_photos_grid.dart
│   │   │       └── spotify_card.dart
│   │   ├── map/
│   │   │   ├── map_page.dart
│   │   │   └── widgets/
│   │   │       └── friend_marker_info.dart
│   │   ├── friends/
│   │   │   ├── friends_page.dart
│   │   │   └── widgets/
│   │   │       └── friend_tile.dart
│   │   ├── chat/
│   │   │   ├── conversations_screen.dart
│   │   │   ├── chat_screen.dart
│   │   │   └── widgets/
│   │   │       └── message_bubble.dart
│   │   └── swipe/
│   │       ├── swipe_screen.dart
│   │       ├── my_matches_screen.dart
│   │       └── widgets/
│   │           ├── tinder_card.dart
│   │           └── match_dialog.dart
│   │
│   └── widgets/                      # componente globale reutilizabile
│       ├── avatar.dart               # CircleAvatar unificat
│       ├── loading_indicator.dart
│       ├── refresh_scroll_view.dart  # CustomScrollView + CupertinoRefresh
│       ├── section_label.dart        # header secțiune (PROFIL, ALTELE etc.)
│       └── story_viewer.dart
│
├── services/                         # singleton-uri tehnice, fără business logic
│   ├── auth_service.dart
│   ├── location_service.dart         # GPS raw stream
│   ├── geocoding_service.dart
│   ├── photo_service.dart
│   └── spotify_service.dart
│
├── firebase_options.dart
└── main.dart                         # DI tree (MultiProvider), app bootstrap
```

---

## Layerele de providere

```
┌──────────────────────────────────────────┐
│  Layer 3 — UI Providers                  │  State local de ecran (scroll, tabs, etc.)
│  ProfileUiProvider, MapUiProvider, ...   │  Trăiesc cât timp trăiește ecranul
├──────────────────────────────────────────┤
│  Layer 2 — Domain Providers              │  Use-case runners, cache, streams
│  UserProvider, FeedProvider, ...         │  Trăiesc la nivel de app (în main.dart)
├──────────────────────────────────────────┤
│  Layer 1 — Infrastructure Providers      │  Auth state, conectivitate
│  AuthStateProvider, ConnectivityProvider │  Trăiesc tot timpul app-ului
└──────────────────────────────────────────┘
         ↓ injectate via MultiProvider în main.dart
```

**Reguli stricte de comunicare între layere:**
- Layer 3 citește din Layer 2, niciodată invers.
- Layer 2 apelează use-case-uri din `domain/`, niciodată direct Firestore.
- Layer 1 nu știe de UI.
- Niciun provider nu importă alt provider direct — primesc interfețe prin constructor.

---

## Principii de implementare (SRP)

| Fișier | O singură responsabilitate |
|--------|---------------------------|
| `*_remote_datasource.dart` | Apeluri Firestore/Firebase, returnează Map/JSON brut |
| `*_model.dart` | Deserializare/serializare JSON ↔ entitate |
| `*_repository_impl.dart` | Orchestrare datasource + conversie model→entitate |
| `*_usecase.dart` | Un singur workflow de business (un call la repository) |
| `*_provider.dart` | State + notifyListeners, fără logică de business |
| `*_screen.dart` | Scaffold + routing, fără logică de date |
| `widgets/*.dart` | Widget pur, primeşte tot prin parametri, fără Provider.of direct |

---

## Faze de execuție și sub-agenți

Fiecare fază se lansează ca un sub-agent long-running separat.
Sub-agentul primește: **fișierele sursă actuale + contractul de ieșire (interfața publică)**.
Sub-agentul scrie codul, rulează `flutter analyze`, și raportează înapoi.

---

### Faza 0 — Core & Constants *(~1-2h, 1 agent)*

**Context pentru agent:**
- Citește `lib/constants/global_variables.dart`, `lib/utils/scroll_utils.dart`
- Citește toate culorile hardcodate din `screens/*.dart` (grep `Color(0xFF`)

**Deliverables:**
- `lib/core/constants/app_colors.dart` — toate culorile ca constante statice
- `lib/core/constants/app_text_styles.dart` — TextStyle-uri reutilizabile
- `lib/core/constants/app_sizes.dart` — spacing, radius, icon sizes
- `lib/core/errors/app_exception.dart` — `AppException`, `NetworkException`, `AuthException`
- `lib/core/utils/scroll_utils.dart` — mutat din `lib/utils/`
- `lib/core/extensions/context_extensions.dart` — `context.colors`, `context.textStyles`

**Criteriu de finalizare:** `flutter analyze` fără erori pe fișierele noi.

---

### Faza 1 — Domain Layer *(~2-3h, 1 agent)*

**Context pentru agent:**
- Citește toate modelele din `lib/models/`, `lib/tinder_models/`
- Citește repository-urile din `lib/repository/`

**Deliverables:**
- `lib/domain/entities/*.dart` — Dart plain objects, fără Firebase
- `lib/domain/repositories/i_*.dart` — interfețe abstracte cu semnăturile exacte
- `lib/domain/usecases/**/*.dart` — câte un fișier per use-case, un singur method `call()`

**Exemplu structură use-case:**
```dart
class GetFeedUsecase {
  const GetFeedUsecase(this._repo);
  final IPostRepository _repo;
  Stream<List<PostEntity>> call(String userId) => _repo.watchFeed(userId);
}
```

**Criteriu de finalizare:** Toate interfețele compilează. Niciun import Firebase în `domain/`.

---

### Faza 2 — Data Layer *(~3-4h, 2 agenți în paralel)*

#### Agent 2A — Remote Datasources
**Context:** Citește `lib/services/*.dart`, `lib/repository/*.dart`, toate apelurile Firestore

**Deliverables:**
- `lib/data/datasources/remote/user_remote_datasource.dart`
- `lib/data/datasources/remote/post_remote_datasource.dart`
- `lib/data/datasources/remote/friend_remote_datasource.dart`
- `lib/data/datasources/remote/message_remote_datasource.dart`
- `lib/data/datasources/remote/location_remote_datasource.dart`
- `lib/data/datasources/remote/swipe_remote_datasource.dart`

Fiecare datasource returnează `Map<String, dynamic>` sau `Stream<Map<String, dynamic>>`.
Nicio logică de business, nicio conversie la entitate.

#### Agent 2B — Models & Repository Impls
**Context:** Citește modelele existente + interfețele din Faza 1

**Deliverables:**
- `lib/data/models/*.dart` — adaugă `fromMap()`, `toMap()`, `toEntity()`
- `lib/data/repositories/*_impl.dart` — implementează interfețele din `domain/`
- `lib/data/datasources/local/feed_local_datasource.dart` — Hive wrapper (din `feed_cache_service`)

**Criteriu de finalizare:** Ambii agenți → `flutter analyze` clean pe `data/`.

---

### Faza 3 — Provider Layer *(~2-3h, 1 agent)*

**Context pentru agent:**
- Citește toți providerii existenți din `lib/providers/`
- Citește use-case-urile din Faza 1

**Deliverables:**
- `lib/presentation/providers/infrastructure/auth_state_provider.dart`
- `lib/presentation/providers/domain/user_provider.dart`
- `lib/presentation/providers/domain/friends_provider.dart`
- `lib/presentation/providers/domain/feed_provider.dart`
- `lib/presentation/providers/domain/location_provider.dart` — înlocuiește `friend_location_provider`
- `lib/presentation/providers/domain/messaging_provider.dart`
- `lib/presentation/providers/domain/swipe_provider.dart`

**Reguli pentru agent:**
- Fiecare provider primește use-case-urile prin constructor (nu le instanțiază singur)
- `dispose()` anulează toate stream subscriptions
- Nicio referință la Firebase, Firestore sau Geolocator direct

**Criteriu de finalizare:** `flutter analyze` clean + DI tree compilează în `main.dart`.

---

### Faza 4 — Widgets reutilizabile *(~2-3h, 1 agent)*

**Context pentru agent:**
- Citește `lib/screens/profile_page.dart`, `lib/screens/settings_page.dart`,
  `lib/screens/user_profile_screen.dart`, `lib/widget/`, `lib/widgets/`
- Identifică tot ce se repetă: avatar, tile, secțiune header, scroll view cu refresh

**Deliverables:**
```
lib/presentation/widgets/
├── avatar.dart                  # CircleAvatar unificat cu fallback icon
├── loading_indicator.dart       # CircularProgressIndicator styled
├── refresh_scroll_view.dart     # CustomScrollView + CupertinoSliverRefreshControl
├── section_label.dart           # Text uppercase gri (PROFIL, ALTELE, etc.)
├── settings_tile.dart           # Tile cu icon + label + arrow din settings_page
└── story_viewer.dart            # consolidat din widget/ și widgets/
```

**Exemplu `refresh_scroll_view.dart`:**
```dart
class RefreshScrollView extends StatelessWidget {
  const RefreshScrollView({
    super.key,
    required this.onRefresh,
    required this.slivers,
  });
  final Future<void> Function() onRefresh;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: const NoGlowScrollBehavior(),
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: CappedBouncingScrollPhysics(maxOverscroll: 48),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: onRefresh),
        ...slivers,
      ],
    ),
  );
}
```

**Criteriu de finalizare:** Widgetele noi nu au niciun `Provider.of` sau `context.read` direct.

---

### Faza 5 — Screen Refactor *(~4-6h, 3 agenți în paralel)*

#### Agent 5A — Profile & Settings screens
**Fișiere sursă:** `profile_page.dart`, `user_profile_screen.dart`, `settings_page.dart`, `repository/edit_profile.dart`

**Deliverables:**
```
lib/presentation/screens/profile/
├── profile_page.dart             # ≤ 150 linii, folosește _ProfileHeader, RefreshScrollView
├── user_profile_screen.dart      # ≤ 200 linii
├── edit_profile_screen.dart      # mutat din repository/
├── settings_page.dart            # ≤ 150 linii, folosește SettingsTile, SectionLabel
└── widgets/
    ├── profile_header.dart       # gradient header + avatar + bio
    ├── profile_stats_grid.dart   # grid cu țări/poze/prieteni
    ├── profile_photos_grid.dart  # SliverGrid cu poze
    └── spotify_card.dart         # card Spotify current track
```

#### Agent 5B — Home, Feed & Friends screens
**Fișiere sursă:** `home_screen.dart`, `feed_page.dart`, `friends_page.dart`

**Deliverables:**
```
lib/presentation/screens/home/
├── home_screen.dart              # shell tabs, ≤ 100 linii
└── widgets/
    └── post_card.dart            # extras din home_screen

lib/presentation/screens/feed/
└── feed_page.dart                # ≤ 150 linii

lib/presentation/screens/friends/
├── friends_page.dart             # ≤ 150 linii
└── widgets/
    └── friend_tile.dart
```

#### Agent 5C — Map, Chat & Swipe screens
**Fișiere sursă:** `map_page.dart`, `chat_screen.dart`, `conversations_screen.dart`,
`swipe_screen.dart`, `my_matches_screen.dart`, `tinder_card/`

**Deliverables:**
```
lib/presentation/screens/map/
├── map_page.dart                 # ≤ 200 linii, citește din LocationProvider
└── widgets/
    └── friend_marker_info.dart

lib/presentation/screens/chat/
├── conversations_screen.dart
├── chat_screen.dart
└── widgets/
    └── message_bubble.dart

lib/presentation/screens/swipe/
├── swipe_screen.dart
├── my_matches_screen.dart
└── widgets/
    ├── tinder_card.dart
    └── match_dialog.dart
```

**Criteriu comun pentru agenții 5A/5B/5C:**
- Niciun ecran nu face apeluri Firestore direct — totul prin providere
- Niciun fișier > 300 linii
- `flutter analyze` clean

---

### Faza 6 — Wiring & main.dart *(~1-2h, 1 agent)*

**Context pentru agent:**
- Citește `lib/main.dart` curent
- Citește toate providerii din Faza 3

**Deliverables:**
- `lib/main.dart` — `MultiProvider` cu toți providerii injectați corect în ordine (infrastructure → domain → ui)
- Eliminarea oricărui `addPostFrameCallback` cu logică de business — înlocuit cu `init()` în provider

**Structură MultiProvider țintă:**
```dart
MultiProvider(
  providers: [
    // Layer 1 — Infrastructure
    ChangeNotifierProvider(create: (_) => AuthStateProvider()),
    // Layer 2 — Domain (primesc use-case-uri prin create)
    ChangeNotifierProxyProvider<AuthStateProvider, UserProvider>(
      create: (_) => UserProvider(GetUserUsecase(UserRepositoryImpl(...))),
      update: (_, auth, prev) => prev!..onAuthChanged(auth.userId),
    ),
    ChangeNotifierProvider(create: (_) => LocationProvider(
      WatchFriendLocationsUsecase(...),
      PublishLocationUsecase(...),
    )),
    // ... restul
  ],
  child: const VascoApp(),
)
```

---

### Faza 7 — Cleanup & Validare *(~1h, 1 agent)*

**Deliverables:**
- Ștergere fișiere vechi din `lib/screens/`, `lib/providers/`, `lib/repository/`, `lib/widget/`, `lib/widgets/`, `lib/tinder_card/`, `lib/tinder_models/`, `lib/tinder_services/`
- Verificare `flutter analyze` → zero warnings
- Verificare că nu mai există importuri circulare

---

## Timeline estimativ

| Fază | Durată | Agenți | Blocker |
|------|--------|--------|---------|
| 0 — Core/Constants | 1-2h | 1 | — |
| 1 — Domain | 2-3h | 1 | după Faza 0 |
| 2 — Data Layer | 3-4h | 2 (paralel) | după Faza 1 |
| 3 — Provider Layer | 2-3h | 1 | după Faza 2 |
| 4 — Widgets | 2-3h | 1 | după Faza 0 |
| 5 — Screens | 4-6h | 3 (paralel) | după Faza 3 și 4 |
| 6 — Wiring | 1-2h | 1 | după Faza 5 |
| 7 — Cleanup | 1h | 1 | după Faza 6 |
| **Total** | **~16-24h** | | |

---

## Checklist per agent (template)

Fiecare agent primește acest checklist și raportează statusul la final:

- [ ] Am citit toate fișierele sursă relevante
- [ ] Am respectat contractul de interfață (semnături de metode, tipuri de return)
- [ ] Niciun fișier depășește 300 de linii
- [ ] Niciun import circular
- [ ] Nicio logică de business în widgets sau screens
- [ ] `flutter analyze` → 0 erori, 0 warnings
- [ ] Am documentat orice decizie non-obvioasă cu un singur comentariu inline

---

## Note de migrare

1. **`FriendLocationProvider`** devine `LocationProvider` în `presentation/providers/domain/`.
   Aceeași logică, mutată corect — nu se rescrie de la zero.

2. **`repository/edit_profile.dart`** → `presentation/screens/profile/edit_profile_screen.dart`.
   Conținut identic, doar locație nouă.

3. **`feed_cache_service.dart`** → split în `data/datasources/local/feed_local_datasource.dart`
   (Hive calls) + `domain/usecases/feed/cache_feed_usecase.dart` (logica de when-to-cache).

4. **`widget/` și `widgets/`** se unifică în `presentation/widgets/`.
   `story_viewer.dart` duplicat → păstrat o singură versiune.

5. **`tinder_card/`, `tinder_models/`, `tinder_services/`** → mutate integral în
   `presentation/screens/swipe/widgets/` și `domain/entities/` respectiv `services/`.

6. **`helpers/`** → `core/utils/` pentru `date_utils`, `core/extensions/` pentru helpers de context.
