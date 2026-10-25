# 📚 Documentazione Tecnica di NaRotta

Benvenuto nella documentazione tecnica e architetturale di **NaRotta**, il navigatore satellitare 100% offline per dispositivi mobili e tablet basato su tecnologie open-source e dati OpenStreetMap.

---

## 🗂️ Indice dei Documenti

I documenti architetturali e operativi sono strutturati in ordine progressivo:

| ID | Documento | Oggetto / Scopo |
| :--- | :--- | :--- |
| **01** | [`01_generazione_mappe.md`](01_generazione_mappe.md) | **Pipeline e servizio mappe offline**: Geofabrik, Planetiler, Valhalla, SQLite FTS5, routing trans-regionale (es. Trento-Milano), viaggi transcontinentali (es. Calabria-Capo Nord), profili "No Autostrade" e gestione delle 7 criticità tecniche. |
| **02** | [`02_architettura_map_builder.md`](02_architettura_map_builder.md) | **Architettura Tecnica `NaRotta.MapBuilder` (CLI C# .NET 10)**: App multipiattaforma Windows/Linux per download, slicing multi-risoluzione Vector Tiles, parser PBF a 2 passaggi con `STRtree` e compilazione grafi Valhalla. |
| **03** | [`03_funzionamento_build_world_e_mappatura_file.md`](03_funzionamento_build_world_e_mappatura_file.md) | **Guida Operativa `build-world` & Mappatura File**: Mappatura esaustiva di ogni file sorgente e generato, funzionamento passo-passo della pipeline mondiale, sorgenti dati, gestione RAM/I-O e artefatti di output. |
| **04** | [`04_web_dashboard_e_deploy_coolify.md`](04_web_dashboard_e_deploy_coolify.md) | **Web Dashboard & Deploy Remoto Coolify**: Applicazione Web ASP.NET Core .NET 10, monitoraggio real-time con SSE, verifica aggiornamenti OpenStreetMap/Geofabrik, start/stop controllato, architettura container Dockerfile e configurazione Coolify. |
| **05** | *In definizione* | **Architettura Mobile & Integrazione Nativa**: Flutter, MapLibre Native, Valhalla C++ FFI e TTS. |
| **06** | *In definizione* | **UI/UX & Flussi di Navigazione**: Layout adattivo per smartphone/tablet, HUD, tema giorno/notte e gestione rotte. |

---

## 📌 Convenzioni
- **Lingua**: Tutta la documentazione è redatta inizialmente in **Italiano** per consolidare le scelte progettuali, per poi essere tradotta/adattata in lingua inglese in vista del rilascio pubblico.
- **Principio Open Source**: Ogni componente e formato adottato deve essere privo di licenze proprietarie a pagamento, compatibile con licenze MIT, Apache 2.0, BSD-2-Clause o ODbL (OpenStreetMap).
