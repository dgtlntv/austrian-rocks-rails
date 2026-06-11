# Backlog
<!-- Ordered top→bottom by priority. One line each. Keep terse. -->
<!-- [id] prio:<p> size:<s> status:<status> [phase:<id-Pn>] tags:<a,b> — <title> [→ work/<id>] -->
<!-- prio: high|med|low · size: S|M|L|XL · status: ready|spec|plan|implement|review|blocked|done -->
- [0011] prio:high size:M status:ready tags:maps,fonts,cdn — Self-host Inter glyphs for shared map styles
- [0013] prio:med size:S status:ready tags:maps,tiles,bug — Bug: map tiles GeoJSON exporter silently falls back to http://localhost:3000 when asset_host is unset (lib/map_tiles/geojson_exporter.rb:409), baking localhost photo URLs into published PMTiles — caused Chrome's Local Network Access permission prompt on austrian.rocks when clicking a problem. Should fail loudly (raise / skip photo URL) instead.
- [0003] prio:med size:S status:ready tags:ruby,maintenance — Update Ruby version to 4.0
- [0010] prio:low size:M status:ready tags:maps,tiles,basemap — Replace testing basemap endpoint once production basemap.at style/source is ready in Q3 2026
