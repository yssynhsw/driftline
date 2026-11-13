# Gestion 2 — Voyages & itinéraires intelligents (soutenance)

## 1. Architecture du module

```
UI (screens/widgets)
  → TripRepository (règles + ownership userId)
    → TripDatabase (sqflite CRUD)
      → driftline.db (partagée avec UserStore)
Services externes (Gestion 2):
  GeminiItineraryGenerator (+ proxy Spring Boot)
  OpenMeteoForecastService
  DestinationCoverService (Wikipedia/Commons)

Note: OpenTripMap / OpenRouteService appartiennent à la Gestion 3
(autres membres). Des clients optionnels peuvent exister dans le dépôt
mais ne font pas partie de la grille Gestion 2.
```

Fichiers clés : `lib/src/trips/*`, entrée UI depuis `shell.dart` → `TripsListScreen`.

## 2. SQFlite

- Package Flutter `sqflite` (pas Hive/Firebase pour le métier).
- Fichier unique `driftline.db`, version 8, `PRAGMA foreign_keys = ON`.
- Ouverture via `UserStore` ; Gestion 2 s’attache avec `TripRepository.attached()`.

## 3. Relations

- `trips (id_trip)` 1—N `itinerary_days (trip_id)` ON DELETE CASCADE
- `itinerary_days (id)` 1—N `itinerary_steps (day_id)` ON DELETE CASCADE
- `trips.user_id` → `users.id_user`

## 4. CRUD

- Voyages : create/update/delete/list/getById (`TripRepository`)
- Journées : create/update/delete/reorder
- Activités : create/update/delete/reorder (`createStep`…)
- Modifier une journée **ne remplace plus** les steps (`syncSteps: false` par défaut)

## 5. Itinéraires

- Écran jour : liste des activités (horaires, durée, coût, description)
- Formulaire dédié `step_form.dart`
- IA : `replaceItineraryFromAi` insère jours + steps structurés

## 6. Budget

`BudgetEngine.analyze` : privilégie la somme des coûts d’activités d’un jour ; sinon budget estimé du jour. Affiche dépassement + tips.

## 7. Conflits

`ConflictService` : hors dates, fin &lt; début, overlap, gap &lt; 15 min, &gt; 8 steps/jour. Affichés détails voyage + écran jour.

## 8. Gemini

- Direct : `GEMINI_API_KEY` via `--dart-define`
- Camarades : proxy Spring `POST /api/v1/gemini/generate` + `GEMINI_PROXY_URL` / token
- Parsing JSON robuste (fences markdown, multi-parts)
- Persistance via `replaceItineraryFromAi`

## 9. APIs externes

| API | Rôle | Config |
|-----|------|--------|
| Gemini | Itinéraire IA | clé ou proxy |
| Open-Meteo | Météo + géocodage | Aucune clé |
| Wikimedia/Wikipedia | Cover + galerie (UX) | Aucune clé |

OpenTripMap / OpenRouteService = **Gestion 3** (hors grille Gestion 2).

## 10. Gestion des erreurs

Timeouts HTTP, messages métier (`TripStoreException`, `GeminiException`, …), retries Gemini, UI loading/empty/error.

## 11. Sécurité des clés

Jamais hardcodées dans le code. `.env.local` gitignored → `dart_defines.json` via scripts. Proxy garde la clé Gemini côté serveur.

## 12. Scénarios de démo

1. Créer un voyage (pays → cover)
2. Ajouter une journée puis 2–3 activités (horaires)
3. Voir conflits / budget
4. Météo Open-Meteo
5. Galerie Wikimedia
6. (Si proxy/clé) Générer itinéraire IA → modifier une activité

---

## 30 questions professeur (oral)

### Architecture (1–6)

1. **Organisation ?** UI → Repository → SQFlite + services API.  
   *Fichiers :* `trip_repository.dart`, `trip_database.dart`

2. **Rôle du Repository ?** Valide, vérifie le propriétaire, orchestre DB/services.  
   *Exemple :* `createStep` appelle `validateStep` puis `insertStep`.

3. **Pourquoi une DB partagée ?** Une seule `driftline.db` avec les users.  
   *Fichier :* `store.dart` + `TripRepository.attached()`

4. **Couches ?** Screens n’écrivent pas de SQL ; `TripDatabase` encapsule sqflite.

5. **Navigation Gestion 2 ?** Shell « Mes voyages » → liste → détails → itinéraire/jour/IA.

6. **Tests ?** FFI sqflite en mémoire/fichier temp ; HTTP mockés.

### SQFlite (7–14)

7. **Pourquoi SQFlite ?** Persistance locale offline standard Flutter.

8. **SQLite vs SQFlite ?** Moteur C vs plugin Dart.

9. **Tables ?** `trips`, `itinerary_days`, `itinerary_steps`.

10. **CASCADE ?** Supprimer un voyage efface jours et activités (transaction `deleteTripCascade`).

11. **Transactions ?** Insert jour + steps, reorder, delete.

12. **Migrations ?** v5–v8 (`createTable`, migrateV6/V7/V8).

13. **Isolation users ?** Toutes les ops passent par `_ownedTrip(userId)`.

14. **updateDay et steps ?** `syncSteps: false` par défaut pour ne pas écraser.

### Métier (15–22)

15. **Créer voyage ?** Formulaire → validation → cover/galerie → insert.

16. **Activités ?** CRUD sur `itinerary_steps` depuis l’écran jour.

17. **Horaires ?** HH:MM validés ; durée calculée dans `ItineraryStep.durationMinutes`.

18. **Conflits ?** `ConflictService.analyze`.

19. **Budget ?** `BudgetEngine` + barre dans détails.

20. **IA enregistrement ?** `replaceItineraryFromAi` remplace les jours.

21. **Modifier proposition IA ?** Éditer/supprimer steps ensuite dans l’UI.

22. **Dates ?** Retour ≥ départ ; jour dans la fenêtre voyage.

### APIs (23–30)

23. **Gemini ?** generateContent ou proxy ; JSON jours/steps.

24. **Protection clé ?** dart-define / proxy serveur.

25. **Open-Meteo ?** Geocoding + forecast, panneau météo.

26. **Images ?** Wikipedia/Commons, pas Unsplash en prod.

27. **OpenTripMap ?** Hors Gestion 2 — responsabilité Gestion 3.

28. **OpenRouteService ?** Hors Gestion 2 — responsabilité Gestion 3.

29. **Hors ligne ?** CRUD local OK ; APIs affichent erreur.

30. **Firebase ?** Auth locale sqflite ; `firebase_uid` est un id local, pas Firebase Auth.
