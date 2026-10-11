# 📚 Documentazione Tecnica di NaRotta

Benvenuto nella documentazione tecnica e architetturale di **NaRotta**, il navigatore satellitare 100% offline per dispositivi mobili e tablet basato su tecnologie open-source e dati OpenStreetMap.

---

## 🗂️ Indice dei Documenti

I documenti architetturali e operativi sono strutturati in ordine progressivo:

| ID | Documento | Oggetto / Scopo |
| :--- | :--- | :--- |
| **01** | [`01_generazione_mappe.md`](01_generazione_mappe.md) | **Pipeline e servizio mappe offline**: Geofabrik, Planetiler, Valhalla, SQLite FTS5, routing trans-regionale (es. Trento-Milano), viaggi transcontinentali (es. Calabria-Capo Nord), profili "No Autostrade" e stima volumetrica Europa (~45 GB). |
| **02** | *In definizione* | **Architettura Mobile & Integrazione Nativa**: Flutter, MapLibre Native, Valhalla C++ FFI e TTS. |
| **03** | *In definizione* | **UI/UX & Flussi di Navigazione**: Layout adattivo per smartphone/tablet, HUD, tema giorno/notte e gestione rotte. |

---

## 📌 Convenzioni
- **Lingua**: Tutta la documentazione è redatta inizialmente in **Italiano** per consolidare le scelte progettuali, per poi essere tradotta/adattata in lingua inglese in vista del rilascio pubblico.
- **Principio Open Source**: Ogni componente e formato adottato deve essere privo di licenze proprietarie a pagamento, compatibile con licenze MIT, Apache 2.0, BSD-2-Clause o ODbL (OpenStreetMap).
