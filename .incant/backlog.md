# Backlog
<!-- Ordered top→bottom by priority. One line each. Keep terse. -->
<!-- [id] prio:<p> size:<s> status:<status> [phase:<id-Pn>] tags:<a,b> — <title> [→ work/<id>] -->
<!-- prio: high|med|low · size: S|M|L|XL · status: ready|spec|plan|implement|review|blocked|done -->
- [0012] prio:med size:M status:spec tags:maps,maintenance,deploy — Remove the remaining legacy Mapbox references now that runtime maps use MapLibre: delete lib/tasks/mapbox.rake and its namespace/output paths, remove the deploy volume/path austrian_rocks_mapbox:/austrian-rocks-maps/mapbox, and clean up incidental comments in routes/admin map code while preserving intentional tests that assert no Mapbox runtime assets. → work/0012-remove-legacy-mapbox-references
- [0003] prio:med size:S status:ready tags:ruby,maintenance — Update Ruby version to 4.0
