# Inter v1 MapLibre glyphs

This directory contains committed MapLibre runtime glyph PBF assets for the shared Austrian Rocks styles. They are published under the existing style CDN prefix at:

```text
map_styles/fonts/inter-v1/{fontstack}/{range}.pbf
```

The approved font stack directories for `inter-v1` are exactly:

- `Inter Light`
- `Inter Regular`
- `Inter Medium`
- `Inter Bold`
- `Inter Medium Italic`
- `Inter Bold Italic`

The PBF files were copied from `tmp/font-maker-2026-06-11T14_25_38.391Z/`, generated on 2026-06-11. This repository commits the generated runtime `.pbf` glyph assets only; do not add Inter `.ttf`, `.otf`, `.woff`, or `.woff2` source font binaries here.

Inter is copyright The Inter Project Authors and licensed under the SIL Open Font License 1.1; see `LICENSE.md` for the provenance note.

Normal PMTiles/style/sprite releases do not upload these font glyphs. Publish this tree only through the dedicated static font publish path. Future font updates must create a new immutable versioned directory such as `fonts/inter-v2` instead of mutating `inter-v1`.
