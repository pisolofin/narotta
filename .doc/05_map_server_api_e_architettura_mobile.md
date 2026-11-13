# 05 - Map Server API (`NaRotta.MapServer.Api`) & Architettura Mobile

Questo documento copre due ambiti complementari:
1. **Distribuzione HTTP (`NaRotta.MapServer.Api` in `map-api/`)**: l'API REST che espone `manifest.json`, il calcolo spaziale delle Geo-Cells e lo streaming resumabile dei pacchetti.
2. **Architettura Client Mobile (`flutter/`)**: stato attuale dei servizi Flutter e roadmap di integrazione nativa (MapLibre Native, Valhalla C++ FFI, SQLite FTS5 e TTS).

---

## 1. `NaRotta.MapServer.Api` (`map-api/`)

Il servizio ASP.NET Core (.NET 10) legge la directory condivisa prodotta da `NaRotta.MapBuilder` (montata su `STORAGE_DIR` o `OUTPUT_DIR`) e serve i client NaRotta.

### 1.1 Endpoint Esposti

| Metodo | Endpoint | Descrizione |
| :--- | :--- | :--- |
| `GET` | `/health`, `/api/v1/health` | Healthcheck del servizio (`status: "Healthy"`). |
| `GET` | `/api/v1/manifest` | Restituisce il catalogo `manifest.json` (schema `v2.2`), con cache in memoria di 30 secondi (e fallback di sviluppo se il file non è ancora presente). |
| `GET` | `/api/v1/regions` | Elenco delle regioni compilate presenti nel manifest. |
| `GET` | `/api/v1/regions/{*regionId}` | Metadati di una singola regione (es. `europe/italy`). |
| `POST` | `/api/v1/cells/query-lasso` | Riceve `{ pointList, layerList }` e calcola le celle `0.5° × 0.5°` intersecate dal poligono disegnato dall'utente, restituendo pesi stimati/reali e URL di download. |
| `GET` | `/api/v1/cells/query-bbox` | Calcola le celle `0.5° × 0.5°` intersecate da una bounding box (`minLon`, `minLat`, `maxLon`, `maxLat`, `layers`). |
| `GET` | `/api/v1/cells/{cellId}` | Dettagli e URL di download per una singola cella (es. `N45_50_E010_50`). |
| `GET` | `/api/v1/download/{*filePath}` | Download diretto dei file (`.mbtiles`, `.db`, `.tar`, `.zip`) con **HTTP 206 Partial Content** (`enableRangeProcessing: true`) e protezione contro directory traversal. |

### 1.2 Configurazione & Variabili d'Ambiente

- `PORT`: porta di ascolto HTTP (default `5001`, oltre alla porta `80` per proxy Coolify).
- `STORAGE_DIR` / `OUTPUT_DIR`: directory condivisa dove `NaRotta.MapBuilder` scrive `manifest.json`, `overview/`, `assets/`, `cells/` e `regions/`.
- `PUBLIC_BASE_URL`: URL pubblico base usato per comporre i link di download restituiti da `query-lasso` / `query-bbox`.

---

## 2. Architettura Client Mobile (`flutter/`)

### 2.1 Componenti Attualmente Implementati
- **`MapServerService`**: gestione URL server (preset locale/LAN/produzione o custom) e verifica `/health`.
- **`MapDownloadService`**: download resumabili a blocchi (`.part` + header HTTP `Range: bytes=<offset>-`), pausa/ripresa, cancellazione con pulizia `.part`, registro locale delle zone scaricate e rimozione orfani.
- **`GeoCatalogService` & `GeoCellService`**: catalogo offline di stati/regioni/città e calcolo geometrico delle celle `0.5° × 0.5°`.
- **`MapView` & `MapGridPainter` / `WorldSelectionPainter`**: rendering vettoriale custom ad alte prestazioni per mappa base mondiale, griglia adattiva, selezione a lazo e stati download (tema chiaro/scuro centralizzato in `AppColors`).
- **`LocationService` & `SettingsService`**: telemetria GPS, bussola, lingua, tema e preferenza `wifiOnlyDownload`.

### 2.2 Roadmap Integrazione Nativa (Fase 2)
1. **MapLibre Native (Vector Tiles `.mbtiles`)**:
   - Collegare un `TileProvider` / server HTTP locale in-app che unisca `overview/world_overview.mbtiles` (Z0–7) con le celle `<CELL_ID>_tiles_*.mbtiles` scaricate localmente (oppure tramite merge SQLite `INSERT OR REPLACE`), applicando `style-day.json` / `style-night.json` da `map_assets.zip`.
2. **Valhalla C++ via FFI**:
   - Integrare le librerie native Valhalla (iOS/Android) puntando alla cartella unificata `/valhalla_tiles/`.
   - Completare nella pipeline `MapBuilder` la build continentale (per continuità `GraphId` transfrontaliera) e la dorsale globale Livello 0/1 necessaria alla Modalità 3 (*Smart Corridor*).
3. **Motore di Ricerca SQLite FTS5 / R-Tree & `user_data.db`**:
   - Interrogare direttamente i file `<region>_search.db` per ricerche offline e prossimità POI, affiancandoli al database persistente `user_data.db` (preferiti e import/export GPX/KML/GeoJSON/CSV).
4. **Sintesi Vocale (TTS) & Download Guard Wi-Fi**:
   - Collegare il TTS di sistema alle istruzioni di manovra Valhalla e agganciare `SettingsService.wifiOnlyDownload` al controllo rete (`connectivity_plus`) in `MapDownloadService`.

