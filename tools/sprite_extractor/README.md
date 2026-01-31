# Sprite Extractor

Extracts individual sprites from sprite sheets downloaded from [The Spriters Resource](https://www.spriters-resource.com/pc_computer/ageofempiresii/).

## Quick Start

```bash
cd tools/sprite_extractor
source venv/bin/activate  # venv already exists with dependencies

# Grid-based extraction (recommended for structured sheets)
# Output to images/extracted/ first (gitignored), review, then move to assets/
python extract.py "../../images/extra-sprites/SomeSheet.png" "../../images/extracted/output_folder" --grid --margin 10

# Manual extraction for edge cases
python manual_extract.py "../../images/extra-sprites/SomeSheet.png" "output.png" --crop 100 100 200 200 --remove-white
```

## Source Sheets

Source sprite sheets must be downloaded manually from [The Spriters Resource](https://www.spriters-resource.com/pc_computer/ageofempiresii/) and placed in `images/extra-sprites/`.

The `images/` folder is gitignored (large files). Create it if it doesn't exist:
```bash
mkdir -p ../../images/extra-sprites
```

## What This Does

The sprite sheets from Spriters Resource have:
- **Magenta background** (#FF00FF) as the transparency color
- **White grid lines** separating sprites into cells
- **Black text labels** above each sprite

This tool extracts individual sprites by:
1. Detecting the grid structure
2. Extracting content from each cell
3. Converting magenta to transparency
4. Saving as PNGs with alpha channel

## Scripts

### `extract.py` - Main extraction tool

Two modes:

**Grid mode** (`--grid`) - Best for structured sheets like Cursors, Buildings
- Detects white grid lines
- Splits image into cells
- Extracts content from each cell as one sprite (even if content is disconnected)

**Connected component mode** (default) - For irregular layouts
- Finds connected non-background regions
- Each region becomes a sprite
- Can split sprites that have disconnected parts (arrows + icons)

Key options:
- `--margin N` - Padding around sprites (default: 10 recommended)
- `--min-size N` - Ignore components smaller than NxN pixels
- `--prefix NAME` - Output filename prefix

### `manual_extract.py` - For edge cases

When auto-extraction fails, manually specify crop region:
```bash
python manual_extract.py input.png output.png --crop x1 y1 x2 y2 --remove-white
```

## Decisions & Gotchas

### Grid mode is usually better
Connected component mode splits sprites that have disconnected parts (e.g., a cursor icon + a question mark next to it). Grid mode keeps everything in a cell together.

### White filtering is tricky
- Grid lines are white, need to be filtered for detection
- But some sprites CONTAIN white pixels (highlights, flags)
- Solution: Filter white for grid/cell detection, but not when finding content bounds within a cell
- The `crop_to_content` function trims rows/columns that are >80% white (grid remnants) while keeping white sprite content

### Some sprites extend beyond their cells
The flag cursor (cursor_017) had content extending above its grid cell into the cell above. The grid-based extraction couldn't capture it. Solution: use `manual_extract.py` with a custom crop region that spans both cells.

### Margin matters
- Too little margin → sprites get cut off at edges (white highlights trimmed)
- Too much margin → harmless, just extra transparent pixels
- Recommend `--margin 10` for safety

### Grid line detection
Grid lines are detected as rows/columns that are >80% white. The `grid_line_width` parameter (default 2) offsets cell boundaries to skip the grid line pixels.

## File Locations

```
tools/sprite_extractor/     # This tool
images/                     # GITIGNORED
  extra-sprites/            # Source sheets (download manually, large files)
  extracted/                # Temporary extraction output (review here first)
assets/sprites_extracted/   # Extracted sprites ready to use (tracked in git, create when needed)
assets/sprites/             # Active game sprites (used by the game)
```

See `MIGRATION_PLAN.md` for the full workflow of moving sprites from `images/extracted/` → `assets/sprites_extracted/` → `assets/sprites/`.

## Completed Extractions

### Cursors (2025-01-31)
- Source: `PC _ Computer - Age of Empires II - Miscellaneous - Cursors.png`
- Output: `images/extracted/cursors/` (not yet moved to assets)
- Method: `--grid --margin 10`
- Edge case: cursor_017 (flag) extracted manually:
  ```bash
  python manual_extract.py \
      "../../images/extra-sprites/PC _ Computer - Age of Empires II - Miscellaneous - Cursors.png" \
      "../../images/extracted/cursors/cursor_017.png" \
      --crop 553 75 622 173 --remove-white
  ```
- Status: Ready to move to `assets/sprites_extracted/cursors/` when approved

## Next Steps

1. **Extract building sheets** - Archery Range, Stable, Market, Farm (to replace SVG placeholders)
2. **Extract unit sheets** - Find sheets for Archer, Spearman, etc.
3. **Set up MANIFEST.md** - Track what's extracted vs integrated
4. **Integrate sprites** - Move from `sprites_extracted/` to `sprites/`, update game code

## Building Sheets Complexity

Building sheets are more complex than cursors:
- Multiple ages (Dark, Feudal, Castle, Imperial)
- Multiple player colors (Blue, Red, etc.)
- Multiple states (construction, normal, destroyed)
- Will need to decide which variant to use or extract multiple

The grid detection should work, but may need to identify which cell corresponds to which variant.
