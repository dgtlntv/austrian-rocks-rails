# Austrian.rocks

Austrian.rocks is the best way to discover bouldering in Austria.

This is the code powering the
[Austrian.rocks website](https://www.austrian.rocks) and all the backend & data
processing.

## Stack

-   Ruby On Rails
-   PostgreSQL
-   Tailwind CSS
-   [Stimulus](https://stimulus.hotwired.dev) and
    [Turbo](https://turbo.hotwired.dev)

## How to run the app (on a Mac)

### Install homebrew

-   See https://brew.sh/

### Install Ruby

-   `brew install rbenv libyaml`
-   `rbenv install 3.3.5` (replace `3.3.5` with the content of `.ruby-version`)

### Install Postgre

-   cd to the app directory
-   `brew install postgresql`
-   `brew install postgis`
-   `brew services start postgresql`
-   `createdb dump-prod`

### Set up the app

-   cd to the app directory
-   install rails: `sudo gem install rails`
-   `bundle install`
-   `rake db:setup`

### Import prod data

-   `dropdb dump-prod && createdb dump-prod`
-   `psql -d dump-prod < db/dump-prod.sql`
-   `rake db:migrate`

### Run the app

-   `bin/dev`

### Run the app with Docker

-   `bin/docker-dev`
-   The wrapper sources `.kamal/secrets` on the host, exports those values for
    Docker Compose, then starts the `web` and PostGIS services. Docker Postgres
    intentionally uses the local password `password` by default instead of the
    production `POSTGRES_PASSWORD` from Kamal secrets.
-   On first boot with an empty Docker database, the web container restores
    `tmp/db/production.dump` by default, runs migrations, and starts `bin/dev`.
-   If you need to force a fresh restore from the dump, run
    `DEV_DB_RESTORE=always bin/docker-dev`. To skip dump restore entirely, run
    `DEV_DB_RESTORE=never bin/docker-dev`.
-   If the Postgres volume was previously created with a different password,
    reset it with `docker compose down -v` before running `bin/docker-dev` again.
    Override with `DEV_POSTGRES_PASSWORD=...` only if you intentionally want a
    non-default local Docker database password.

### Map development and web map releases

-   The Rails web map uses MapLibre GL, the PMTiles protocol, and Austrian
    Rocks-owned style JSONs derived from basemap.at. No browser map token or
    credentials are required. While Austrian Rocks is still in development,
    those styles derive from Bergwerk GIS's testing-only
    `basemap-at-farbe` style; before production release, switch to the official
    production-ready basemap.at vector style once available.
-   The shared styles include the basemap.at vector stack, lower-opacity
    `gelände` shading, lower-opacity basemap.at Höhenlinien/contours, and
    Austrian Rocks PMTiles overlays.
-   Published map releases use immutable PMTiles/style objects plus a non-cached
    manifest at `https://tiles.austrian.rocks/map_tiles/current.json`.
-   Clients fetch the manifest and load `styles.light` for the Rails web map;
    mobile clients can choose `styles.light` or `styles.dark`.
-   Do not point clients at a mutable PMTiles URL. Each manifest entry references
    the exact versioned PMTiles and style JSON for that release.
-   Run map-tile tests against Docker-hosted PostgreSQL/PostGIS, for example via
    `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/lib/map_tiles'`.

### Optional: JOSM

Josm is an open source tool used by the OpenStreetMap community. We use it to
edit GeoJSON files.

-   Follow the instructions here:
    `https://josm.openstreetmap.de/wiki/Download#macOS`
-   Go to File > Preferences > Plugins
-   Click on the checkbox next to `Fastdraw` and `PicLayer`, and then click on
    OK
-   Restart Josm
-   In the menu bar (on the left), click on `Fast Drawing mode` and then type
    `Q` to enter the options dialog. Click on `Draw closed polygons only`,
    choose `3` for `Starting Epsilon` and `Simplify with initial epsilon` for
    `Enter key mode`

## Contribute

Want to help us improve the app for thousands of climbers? Great!

Here are a few ways you can contribute:

-   Open an issue if you find a bug
-   Open an issue if you want to suggest an improvement
-   Open a Pull Request (please get in touch with us beforehand, though)

We already have a lot of features waiting to be built, and lots of new ideas to
try out! We'd be happy to share the fun with you :)

As the project is still young, the best way to get started is to drop us a line
at hello@austrian.rocks

You can also contribute to our mapping efforts at
https://www.austrian.rocks/en/contribute
