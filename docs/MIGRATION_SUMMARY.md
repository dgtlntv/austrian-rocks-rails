# Migration Summary: Boolder → Austrian.rocks

## Overview

This document provides a comprehensive summary of all changes made to the Rails
application since forking from the original Boolder (Fontainebleau) repository.
This guide is essential for updating the iOS and Android apps to align with the
Austrian.rocks website.

**Original Repository:** https://github.com/boolder-org/boolder-rails **Forked
Repository:** https://github.com/dgtlntv/austrian-rocks-rails **Total Commits
Since Fork:** 55 commits

---

## 1. Branding & Localization Changes

### 1.1 Brand Configuration System

**File:** `config/brand.rb` (new file)

A centralized brand configuration system was implemented to replace hardcoded
Boolder/Fontainebleau references:

```ruby
BRAND_CONFIG = {
  name: "Austrian.rocks",
  slug: "austrian-rocks",
  domains: {
    main: "austrian.rocks",
    www: "www.austrian.rocks",
    assets: "assets.austrian.rocks"
  },
  contact: {
    email: "hello@austrian.rocks"
  }
}
```

**Impact on Mobile Apps:**

-   All brand name references should use `BRAND_CONFIG[:name]`
-   Domain names for API calls should reference `BRAND_CONFIG[:domains]`
-   Contact email updated throughout

### 1.2 Application Module Rename

**File:** `config/application.rb`

```ruby
# Changed from: module Boolder
module AustrianRocks
  class Application < Rails::Application
```

**Impact on Mobile Apps:**

-   Any references to the Rails module name need updating
-   Database names changed (see deployment config)

### 1.3 Language Changes: French → German

**Major Change:** Complete removal of French language support, replaced with
German.

**Changed Locale Files:**

-   `config/locales/fr.yml` → `config/locales/de.yml`
-   `config/locales/activerecord.fr.yml` → `config/locales/activerecord.de.yml`
-   `config/locales/articles.fr.yml` → `config/locales/articles.de.yml`

**Key Translation Examples:**

| English                     | French (removed)         | German (new)           |
| --------------------------- | ------------------------ | ---------------------- |
| Problems                    | Problèmes                | Routen                 |
| Popular areas               | Aires populaires         | Beliebte Regionen      |
| Beginner friendly           | Débutant                 | Anfängerfreundlich     |
| Family friendly             | Famille                  | Familienfreundlich     |
| Dries fast                  | Sèche vite               | Trocknet schnell       |
| Bouldering in Fontainebleau | Escalade à Fontainebleau | Bouldern in Österreich |

**Impact on Mobile Apps:**

-   Remove all French language support
-   Add German language support
-   Default locale should be German (de) with English (en) as secondary
-   Update all UI strings to match new German translations
-   Homepage title: "Bouldern in Österreich" (German) / "Bouldering in Austria"
    (English)

### 1.4 Visual Assets

**Changed Files:**

-   Logo updated: `app/assets/images/`
-   Apple touch icon: `app/assets/images/apple-touch-icon.png`
-   Removed Fontainebleau-specific images (circuit photos, etc.)

**Brand Color:**

-   Brand color is now configurable via `BRAND_CONFIG`
-   Color system updated to support dynamic theming

**Impact on Mobile Apps:**

-   Update app icon and branding assets
-   Implement new brand color scheme throughout the app
-   Remove any Fontainebleau-specific imagery

### 1.5 Copyright & Legal

-   Copyright notice updated to Austrian.rocks
-   Privacy policy and about pages rewritten for Austrian context
-   Contact email: hello@austrian.rocks

---

## 2. Major Structural Changes

### 2.1 Complete Removal of Circuits Feature

**Commit:** c4a0cbcd "Remove circuits"

Circuits (colored boulder circuits common in Fontainebleau) have been
**completely removed** from the application. This is one of the most significant
changes.

**Database Changes:**

-   Dropped `circuits` table entirely
-   Removed from `problems` table:
    -   `circuit_id` (foreign key)
    -   `circuit_number` (string)
    -   `circuit_letter` (string)

**Removed Files:**

-   `app/models/circuit.rb`
-   `app/controllers/circuits_controller.rb`
-   `app/controllers/circuit7a_controller.rb`
-   `app/controllers/admin/circuits_controller.rb`
-   `app/views/circuits/` (entire directory)
-   `app/views/circuit7a/` (entire directory)
-   Circuit-related images and assets

**Removed Routes:**

-   `/circuits`
-   `/circuits/:id`
-   `/circuit7a`

**Impact on Mobile Apps:**

-   **Remove ALL circuit-related features** from iOS/Android apps
-   Remove circuit filtering and display
-   Remove circuit colors and numbering systems
-   Remove any circuit-specific UI components
-   Problems are now standalone or grouped only by area/cluster
-   Update data models to remove circuit relationships

### 2.2 New Hierarchical Structure: Regions → Clusters → Areas

**Major architectural change:** Introduction of a three-tier geographic
hierarchy.

#### Previous Structure (Boolder):

```
Areas → Problems
```

#### New Structure (Austrian.rocks):

```
Regions → Clusters → Areas → Problems
```

**New Model: Region**

Database schema:

```ruby
create_table :regions do |t|
  t.string :name
  t.integer :main_cluster_id
  t.st_point :center, geographic: true
  t.st_point :sw, geographic: true  # southwest bounds
  t.st_point :ne, geographic: true  # northeast bounds
  t.string :slug
  t.string :tags, array: true
  t.boolean :published, default: true
end
```

**Enhanced Model: Cluster**

New fields added:

```ruby
t.integer :region_id         # belongs to region
t.string :slug              # URL-friendly identifier
t.string :tags, array: true # tagging system
t.boolean :published        # publication status
```

Relationship: `belongs_to :region, optional: true`

**Enhanced Model: Area**

Changed fields:

```ruby
# Removed:
t.integer :bleau_area_id
t.text :description_fr
t.text :warning_fr

# Added/Changed:
t.text :description_de      # German description
t.text :warning_de          # German warning
t.integer :cluster_id       # belongs to cluster
```

**Impact on Mobile Apps:**

-   Implement three-tier navigation: Region → Cluster → Area
-   Add Region model with geographic bounds and metadata
-   Update Cluster model with region relationship and publication status
-   Update Area model with cluster relationship
-   Implement region/cluster filtering and display
-   Update map visualization to show regions and clusters
-   Handle hierarchical data loading and caching

### 2.3 New URL Structure

**Previous URL Pattern:**

```
/fontainebleau/areas
/fontainebleau/:area_slug
/fontainebleau/:area_slug/problems
/fontainebleau/:area_slug/:problem_id
```

**New URL Pattern:**

```
/explore                                              # Regions index
/explore/:region_slug                                 # Region show
/explore/:region_slug/:cluster_slug                   # Cluster show
/explore/:region_slug/:cluster_slug/:area_slug        # Area show
/explore/:region_slug/:cluster_slug/:area_slug/problems
/explore/:region_slug/:cluster_slug/:area_slug/:problem_id
```

**Impact on Mobile Apps:**

-   Update deep linking to use new URL structure
-   Update any web views or shared links
-   Implement region and cluster slug handling
-   Update navigation patterns to match hierarchy

### 2.4 Removal of Bleau.info Integration

**Removed:**

-   `bleau_areas` table (completely dropped)
-   `bleau_problems` table (completely dropped)
-   `bleau_info_id` column from problems table
-   All Bleau.info import and sync functionality

**Removed Files:**

-   `app/models/bleau_area.rb`
-   `app/models/bleau_problem.rb`
-   `app/jobs/bleau_import_problem_job.rb`
-   Bleau.info related rake tasks

**Impact on Mobile Apps:**

-   Remove any Bleau.info references or integrations
-   Remove related problem data sync features
-   Remove ascent/rating sync from Bleau.info

---

## 3. Database Schema Changes

### 3.1 Areas Table

**Changes:**

```ruby
# Removed columns:
- bleau_area_id (integer)
- description_fr (text)
- warning_fr (text)

# Added/Renamed columns:
- description_de (text)     # German description
- warning_de (text)         # German warning
- cluster_id (integer)      # foreign key to clusters
```

**Impact on Mobile Apps:**

-   Update Area model to use German descriptions
-   Remove French description handling
-   Add cluster relationship handling

### 3.2 Problems Table

**Changes:**

```ruby
# Removed columns:
- circuit_id (bigint)
- circuit_number (string)
- circuit_letter (string)
- bleau_info_id (integer)

# Added columns:
- description (text)         # Problem-specific description
- video_links (text array)   # Array of video URLs
```

**Impact on Mobile Apps:**

-   Remove circuit-related fields from Problem model
-   Add support for problem descriptions
-   Add support for multiple video links per problem
-   Update problem detail views to show videos

### 3.3 Boulders Table

**Changes:**

```ruby
# Added columns:
- name (string)  # Named boulders feature
```

**Impact on Mobile Apps:**

-   Boulders can now have optional names
-   Display boulder names when available on maps/detail views

### 3.4 New Tables

#### Regions Table (entirely new)

```ruby
create_table :regions do |t|
  t.string :name
  t.integer :main_cluster_id
  t.geography :center
  t.geography :sw
  t.geography :ne
  t.string :slug
  t.string :tags, array: true
  t.boolean :published, default: true
end
```

#### Clusters Table Enhancements

```ruby
# New columns added:
- region_id (integer)
- slug (string)
- tags (string array)
- published (boolean)
```

**Impact on Mobile Apps:**

-   Implement Region model and UI
-   Update Cluster model with new fields
-   Implement region/cluster hierarchy in navigation

---

## 4. Data Export & API Changes

### 4.1 SQLite Database Export

**File:** `lib/tasks/app.rake`

The rake task that exports data to SQLite for mobile apps has been updated with
significant changes:

**Database filename:**

```ruby
# Changed from: boolder.db
# Changed to: austrian-rocks.db
file_name = Rails.root.join("export", "app", "#{BRAND_CONFIG[:slug]}.db")
```

**Areas Table Export Changes:**

```ruby
# Added columns in export:
- description_de (was description_fr)
- warning_de (was warning_fr)
- cluster_id

# Changed localization:
I18n.with_locale(:de)  # was :fr
```

**Problems Table Export Changes:**

```ruby
# Removed from export:
- circuit information (circuit_id, circuit_number, circuit_letter)

# Locale for name fallback:
I18n.with_locale(:de) { p.name_with_fallback }  # German
I18n.with_locale(:en) { p.name_with_fallback }  # English
```

**New: Clusters Table in Export:**

```sql
create table clusters (
  id INTEGER NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  main_area_id INTEGER NOT NULL
)
```

**Impact on Mobile Apps:**

-   Update SQLite import to expect `austrian-rocks.db` filename
-   Update Areas table schema to use `description_de` and `warning_de`
-   Add `cluster_id` to Areas table
-   Remove all circuit-related columns from Problems table
-   Add Clusters table to local database
-   Update search normalization to use German locale
-   Problems now have both German and English name fields

### 4.3 Tilesets and Mapbox Configuration

**Mapbox Account Change:**

-   Changed from: `nmondollot` (Boolder)
-   Changed to: `dgtlntv` (Austrian.rocks)

**Mapbox Style ID:**

```javascript
// Old (Boolder):
style: "mapbox://styles/nmondollot/cl95n147u003k15qry7pvfmq2"

// New (Austrian.rocks):
style: "mapbox://styles/dgtlntv/cmi0wnif6004t01r0araj0ts0"
```

**Problems Tileset ID:**

```javascript
// Old (Boolder):
url: 'mapbox://nmondollot.4xsv235p'
source-layer: 'problems-ayes3a'

// New (Austrian.rocks):
url: 'mapbox://dgtlntv.74oi43iu'
source-layer: 'problems-8pdvh4'
```

**Default Map Bounds:**

```javascript
// Old (Boolder - Fontainebleau):
bounds: [
    [2.4806787, 48.2868427],
    [2.7698927, 48.473906],
]

// New (Austrian.rocks - Austria):
bounds: [
    [9.430320338084726, 46.28576190178245], // Southwest
    [17.230613306834925, 49.18126637161225],
] // Northeast
```

**Layer Configuration Changes:**

-   Removed: Circuit color logic and circuit number text layers
-   Updated: `source-layer` name from `problems-ayes3a` to `problems-8pdvh4`
-   Changed: Default problem circle color from circuit-based to `#878A8D` (gray)
-   Removed: Circuit sorting logic
-   Simplified: Circle radius logic (removed circuit number special sizing)

**Impact on Mobile Apps:**

-   Update Mapbox access token to Austrian.rocks account (`dgtlntv`)
-   Update style ID to: `cmi0wnif6004t01r0araj0ts0`
-   Update problems tileset URL to: `mapbox://dgtlntv.74oi43iu`
-   Update source-layer name to: `problems-8pdvh4`
-   Update default map bounds to Austria coordinates
-   Remove all circuit color and circuit number rendering logic
-   Update problem circle color to uniform gray (#878A8D)
-   Update tileset IDs for:
    -   Areas layer (uses Mapbox style layers)
    -   Clusters layer (uses Mapbox style layers)
    -   Regions layer (new - uses Mapbox style layers)
    -   Problems layer (uses vector tileset as shown above)

---

## 5. Mapbox Configuration Quick Reference

### Complete Mapbox IDs

| Resource              | Boolder (Old)                                          | Austrian.rocks (New)                                |
| --------------------- | ------------------------------------------------------ | --------------------------------------------------- |
| **Mapbox Account**    | `nmondollot`                                           | `dgtlntv`                                           |
| **Style ID**          | `cl95n147u003k15qry7pvfmq2`                            | `cmi0wnif6004t01r0araj0ts0`                         |
| **Full Style URL**    | `mapbox://styles/nmondollot/cl95n147u003k15qry7pvfmq2` | `mapbox://styles/dgtlntv/cmi0wnif6004t01r0araj0ts0` |
| **Problems Tileset**  | `nmondollot.4xsv235p`                                  | `dgtlntv.74oi43iu`                                  |
| **Full Tileset URL**  | `mapbox://nmondollot.4xsv235p`                         | `mapbox://dgtlntv.74oi43iu`                         |
| **Source Layer Name** | `problems-ayes3a`                                      | `problems-8pdvh4`                                   |

### Map Bounds Configuration

| Region                  | Southwest Corner                         | Northeast Corner                          |
| ----------------------- | ---------------------------------------- | ----------------------------------------- |
| **Fontainebleau (Old)** | `[2.4806787, 48.2868427]`                | `[2.7698927, 48.473906]`                  |
| **Austria (New)**       | `[9.430320338084726, 46.28576190178245]` | `[17.230613306834925, 49.18126637161225]` |

**Important Notes:**

-   The style contains pre-configured layers for areas, clusters, and regions
-   These layers are managed in Mapbox Studio and don't need tileset URLs
-   Only the problems layer uses a custom vector tileset
-   Access tokens must be from the `dgtlntv` Mapbox account

---

## 6. Feature Changes & Enhancements

### 6.1 Problem Features

**Added Features:**

1. **Description Field**

    - Problems can now have text descriptions
    - Stored in `description` field on problems table

2. **Video Links**

    - Multiple video links per problem supported
    - Stored as array in `video_links` field
    - UI displays video links with proper formatting

3. **Flexible Grading**

    - Support for slash grades (e.g., "6a/+")
    - Improved grade validation to handle variations

4. **Sorting Without Grades**
    - Problems without assigned grades can now be sorted
    - Previously caused errors in some views

**Impact on Mobile Apps:**

-   Add description display to problem detail view
-   Implement video link display (multiple videos)
-   Handle slash grades in grade parsing
-   Gracefully handle problems without grades in sorting

### 6.2 Named Boulders

**Feature:** Boulders can now have names

**Database Change:**

```ruby
add_column :boulders, :name, :string
```

**Impact on Mobile Apps:**

-   Display boulder names on map markers when available
-   Show boulder names in problem details
-   Allow filtering/searching by boulder name

### 6.3 Area Features

**Enhanced Filtering:**

-   Added cluster dropdown to area filtering
-   Quick filters moved to cluster level
-   "Clusters first" in navigation hierarchy

**Tag System:** Areas support tags:

-   `popular`
-   `beginner_friendly`
-   `family_friendly`
-   `dry_fast`

**Impact on Mobile Apps:**

-   Implement cluster-based area filtering
-   Display area tags with appropriate icons/badges
-   Support tag-based filtering and search

### 6.4 Region & Cluster Features

**Regions:**

-   Can be marked as popular via tags
-   Have cover images
-   Geographic bounds for map display
-   Published/unpublished status

**Clusters:**

-   Belong to regions
-   Can be marked as popular via tags
-   Have cover images
-   Geographic bounds for map display
-   Published/unpublished status
-   Can be exported from admin interface

**Impact on Mobile Apps:**

-   Implement region browsing and display
-   Show cluster groupings within regions
-   Handle published/unpublished status
-   Display cover images for regions and clusters
-   Implement popular tags filtering

---

## 7. Navigation & UI Changes

### 7.1 Main Navigation

**Homepage Changes:**

Previous (Boolder):

```
Title: "Bouldering in Fontainebleau"
Sections:
- Popular areas
- See all areas
- Circuits
```

New (Austrian.rocks):

```
Title: "Bouldern in Österreich" (German) / "Bouldering in Austria" (English)
Sections:
- Popular regions (Beliebte Regionen)
- Explore all regions (Alle Regionen erkunden)
- Clusters
- No circuits section
```

### 7.2 Map Navigation

**Changes:**

-   Removed circuit layer toggle
-   Added region layer
-   Updated cluster visualization
-   Areas show cluster relationship
-   Default line color changed

**Impact on Mobile Apps:**

-   Update map layers to include regions
-   Remove circuit-related map controls
-   Update map interaction for three-tier hierarchy
-   Implement region/cluster/area boundary visualization

### 7.3 Footer & About

**Footer Updates:**

-   Links updated to Austrian.rocks pages
-   Contact email changed
-   Social media links (if any) updated

**About Page:**

-   Completely rewritten for Austrian context
-   New content about Austrian bouldering
-   Updated contributor information

**Impact on Mobile Apps:**

-   Update about/info screens
-   Update footer links in any web views
-   Update contact information

---

## 8. Content Changes

### 8.1 Articles & Guides

**Removed Articles:**

-   Circuit-specific guides
-   Fontainebleau-specific content
-   French-language articles

**Updated Articles:**

-   Beginner's guide adapted for Austria
-   "Choose Area" guide (no longer circuit-based)
-   "Choose Problems" guide (removed circuit filtering)
-   Rules and ethics updated for Austrian context

**Impact on Mobile Apps:**

-   Remove circuit guides from help/info sections
-   Update beginner guide content
-   Update area selection guides
-   Update rules/ethics content for Austrian climbing

### 8.2 Beginner-Friendly Content

**Areas marked as beginner-friendly:**

-   Tagging system using `beginner_friendly` tag
-   Special sorting by problem count
-   Highlighted in navigation

**Impact on Mobile Apps:**

-   Implement beginner-friendly badge/filter
-   Show beginner areas prominently
-   Sort beginner areas by problem count

---

## 9. Assets Server Changes

### 9.1 Domain Changes

**Asset Server URL:**

```
Old: assets.boolder.com
New: assets.austrian.rocks
```

**Topo Image URLs:**

-   All topo images served from assets.austrian.rocks
-   URL structure remains the same
-   Organized by area: `/topos/area-{area_id}/topo-{topo_id}.jpg`

**Cover Images:**

-   Areas: Active Storage attachments
-   Clusters: Active Storage attachments
-   Regions: Active Storage attachments
-   Variants: `:thumb` (400px) and `:medium` (800px)

**Impact on Mobile Apps:**

-   Update all asset URL prefixes to assets.austrian.rocks
-   Update image caching to use new domain
-   Fetch cover images for regions and clusters
-   Image optimization/variants remain the same

### 9.2 Export Directory Structure

```
export/
├── app/
│   ├── austrian-rocks.db        # Main SQLite database
│   └── topos/
│       └── area-{id}/
│           └── topo-{id}.jpg
```

**Impact on Mobile Apps:**

-   Update download paths for assets
-   Database filename changed from `boolder.db` to `austrian-rocks.db`

---

## 10. Configuration & Deployment

### 10.1 Environment Configuration

**Database Names:**

```ruby
# Changed throughout:
development: austrian_rocks_development
test: austrian_rocks_test
production: austrian_rocks_production
```

**Email Addresses:**

```ruby
# All references changed from:
hello@boolder.com
# To:
hello@austrian.rocks
```

### 10.2 SSL & Domains

**SSL Configuration:**

```ruby
# Added subdomain to SSL array
config.force_ssl = true
config.ssl_options = {
  redirect: {
    exclude: ->(request) {
      request.host == BRAND_CONFIG[:domains][:assets]
    }
  }
}
```

### 10.3 Deploy Configuration

**File:** `config/deploy.yml`

Updated for Austrian.rocks hosting infrastructure.

**Impact on Mobile Apps:**

-   API base URL should be configurable
-   Default to `www.austrian.rocks` for production
-   Test environment may use different URLs

---

## 11. API Compatibility Notes

### 11.1 API Endpoints

**File:** `app/controllers/api/v1/topos_controller.rb`

While the routes document doesn't show explicit API changes, the underlying data
structure changes affect API responses:

**Expected JSON Structure Changes:**

**Area Response:**

```json
{
    "id": 1,
    "name": "...",
    "description_de": "...", // was description_fr
    "warning_de": "...", // was warning_fr
    "cluster_id": 1 // new field
    // removed: bleau_area_id
}
```

**Problem Response:**

```json
{
    "id": 1,
    "name": "...",
    "description": "...", // new field
    "video_links": [] // new field
    // removed: circuit_id, circuit_number, circuit_letter, bleau_info_id
}
```

**Cluster Response:**

```json
{
    "id": 1,
    "name": "...",
    "region_id": 1, // new field
    "slug": "...", // new field
    "published": true // new field
}
```

**Region Response (entirely new):**

```json
{
  "id": 1,
  "name": "...",
  "slug": "...",
  "center": { "lat": ..., "lng": ... },
  "sw": { "lat": ..., "lng": ... },
  "ne": { "lat": ..., "lng": ... },
  "published": true
}
```

**Impact on Mobile Apps:**

-   Update all data model classes
-   Update API response parsing
-   Handle new hierarchical structure in API calls
-   Implement region API calls
-   Remove circuit-related API code

---

## 12. Search & Filtering

### 12.1 Search Changes

**Removed:**

-   Circuit search
-   Circuit filtering in problem search
-   Bleau.info cross-references

**Updated:**

-   Area search now includes cluster context
-   Normalized search uses German locale
-   Search normalization function updated:
    ```ruby
    I18n.with_locale(:de) { I18n.transliterate(string) }
    ```

**Impact on Mobile Apps:**

-   Remove circuit search/filter UI
-   Update search to use German normalization
-   Implement cluster-based filtering
-   Add region-based filtering

### 12.2 Quick Filters

**Location Changes:**

-   Quick filters moved from area level to cluster level
-   "Dry fast" filter now at cluster level
-   Beginner-friendly areas highlighted at region level

**Impact on Mobile Apps:**

-   Relocate quick filter UI from area to cluster views
-   Update filter logic to work at cluster level

---

## 13. Mapbox & Visualization

### 13.1 Mapbox Style Changes

**Updated:**

-   Mapbox style URL changed to Austrian.rocks account
-   Tileset IDs updated
-   Layer IDs updated:
    -   Removed: circuits layer
    -   Added: regions layer
    -   Updated: clusters layer (with region context)
    -   Updated: areas layer (with cluster context)

### 13.2 Default Map Settings

**Changes:**

-   Default center point: Austria (not Fontainebleau)
-   Default zoom levels adjusted
-   Default line color for problems changed

**Impact on Mobile Apps:**

-   Update initial map center to Austria coordinates
-   Update default zoom/bounds
-   Update problem line drawing color
-   Update Mapbox style URL
-   Update all layer filters and expressions

---

## Appendix A: Database Schema Comparison

### Areas Table

| Column         | Boolder | Austrian.rocks | Notes       |
| -------------- | ------- | -------------- | ----------- |
| id             | ✓       | ✓              | Unchanged   |
| name           | ✓       | ✓              | Unchanged   |
| slug           | ✓       | ✓              | Unchanged   |
| bleau_area_id  | ✓       | ✗              | **Removed** |
| cluster_id     | ✗       | ✓              | **Added**   |
| description_fr | ✓       | ✗              | **Removed** |
| description_de | ✗       | ✓              | **Added**   |
| description_en | ✓       | ✓              | Unchanged   |
| warning_fr     | ✓       | ✗              | **Removed** |
| warning_de     | ✗       | ✓              | **Added**   |
| warning_en     | ✓       | ✓              | Unchanged   |

### Problems Table

| Column         | Boolder | Austrian.rocks | Notes                   |
| -------------- | ------- | -------------- | ----------------------- |
| id             | ✓       | ✓              | Unchanged               |
| name           | ✓       | ✓              | Unchanged               |
| grade          | ✓       | ✓              | Enhanced (slash grades) |
| circuit_id     | ✓       | ✗              | **Removed**             |
| circuit_number | ✓       | ✗              | **Removed**             |
| circuit_letter | ✓       | ✗              | **Removed**             |
| bleau_info_id  | ✓       | ✗              | **Removed**             |
| description    | ✗       | ✓              | **Added**               |
| video_links    | ✗       | ✓              | **Added**               |
| area_id        | ✓       | ✓              | Unchanged               |
| location       | ✓       | ✓              | Unchanged               |
| steepness      | ✓       | ✓              | Unchanged               |

### Clusters Table

| Column       | Boolder | Austrian.rocks | Notes     |
| ------------ | ------- | -------------- | --------- |
| id           | ✓       | ✓              | Unchanged |
| name         | ✓       | ✓              | Unchanged |
| main_area_id | ✓       | ✓              | Unchanged |
| center       | ✓       | ✓              | Unchanged |
| sw           | ✓       | ✓              | Unchanged |
| ne           | ✓       | ✓              | Unchanged |
| region_id    | ✗       | ✓              | **Added** |
| slug         | ✗       | ✓              | **Added** |
| tags         | ✗       | ✓              | **Added** |
| published    | ✗       | ✓              | **Added** |

### Regions Table

| Column         | Boolder | Austrian.rocks | Notes         |
| -------------- | ------- | -------------- | ------------- |
| (entire table) | ✗       | ✓              | **New table** |

---

## Appendix B: Locale Key Changes

### Homepage

| Key                          | French (removed)      | German (new)           |
| ---------------------------- | --------------------- | ---------------------- |
| views.homepage.title1        | Escalade              | Bouldern               |
| views.homepage.title2        | à Fontainebleau       | in Österreich          |
| views.homepage.popular_areas | Aires populaires      | Beliebte Regionen      |
| views.homepage.all_areas     | Voir toutes les aires | Alle Regionen erkunden |

### Problem Terms

| Key               | French (removed) | German (new) |
| ----------------- | ---------------- | ------------ |
| problem.problems  | Problèmes        | Routen       |
| problem.start     | Départ           | Start        |
| problem.sit_start | Départ assis     | Sitzstart    |
| problem.featured  | En vedette       | Beliebt      |

### Area Tags

| Key                         | French (removed) | German (new)       |
| --------------------------- | ---------------- | ------------------ |
| area.tags.popular           | populaire        | beliebt            |
| area.tags.beginner_friendly | débutant         | anfängerfreundlich |
| area.tags.family_friendly   | famille          | familienfreundlich |
| area.tags.dry_fast          | sèche vite       | trocknet schnell   |
