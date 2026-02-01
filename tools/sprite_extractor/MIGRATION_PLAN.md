# Sprite Migration Plan

Plan for moving extracted sprites into the game assets and tracking their status.

## Prerequisites

1. Download sprite sheets from [The Spriters Resource - AoE2](https://www.spriters-resource.com/pc_computer/ageofempiresii/)
2. Place them in `images/extra-sprites/` (create folder if needed, it's gitignored)

## Proposed Folder Structure

```
assets/
  sprites/                      # Active game sprites (existing)
    buildings/
    units/
    resources/
    ui/

  sprites_extracted/            # NEW: Extracted but not yet used
    cursors/
    archery_range/
    stable/
    ...
    MANIFEST.md                 # Tracking file

images/                         # STAYS GITIGNORED
  extra-sprites/                # Raw source sheets (large files)
  extracted/                    # Temporary extraction output
```

## Workflow

### 1. Extract
```bash
cd tools/sprite_extractor
source venv/bin/activate
python extract.py "../../images/extra-sprites/<Sheet>.png" "../../images/extracted/<name>" --grid --margin 10
```

Output goes to `images/extracted/` first (gitignored, temporary).

### 2. Review & Fix
- Check extracted sprites visually
- Use `manual_extract.py` for any edge cases
- Re-extract with different parameters if needed

### 3. Move to assets
Once happy with extraction:
```bash
mv images/extracted/<name> assets/sprites_extracted/<name>
```

### 4. Update MANIFEST.md
Add entry to `assets/sprites_extracted/MANIFEST.md`:
- Source sheet name
- Extraction date
- Method used (flags, manual fixes)
- List of sprites with identities

### 5. Integrate into game (when needed)
When a sprite is needed in the game:
1. Copy from `sprites_extracted/<folder>/` to `sprites/<category>/`
2. Update game code (scale, offset, etc.)
3. Delete the SVG placeholder
4. Update MANIFEST.md status
5. Remove from `docs/gotchas.md` "Missing Sprites" table

## MANIFEST.md Template

```markdown
# Extracted Sprites Manifest

## Extraction Log
| Source Sheet | Extracted To | Date | Method | Notes |
|--------------|--------------|------|--------|-------|
| Cursors.png | cursors/ | 2025-01-31 | --grid --margin 10 | cursor_017 manual fix |

## Placeholder Replacements
| Placeholder | Status | Replacement | Notes |
|-------------|--------|-------------|-------|
| buildings/archery_range.svg | TODO | archery_range/ | |
| units/archer.svg | TODO | | Need unit sheet |

## Sprites by Folder

### cursors/
| File | Identity | In Game | Notes |
|------|----------|---------|-------|
| cursor_000.png | Attack sword | No | |
| cursor_001.png | Hourglass | No | |
...
```

## Current State

### Source Sheets Downloaded (in `images/extra-sprites/`)
- Buildings - Archery Range.png
- Buildings - Barracks.png
- Buildings - Building Foundations & Rubble.png
- Buildings - Castle.png
- Buildings - Dock.png
- Buildings - Fish Trap.png
- Buildings - House.png
- Buildings - Lumber Camp.png
- Buildings - Market & Feitoria.png
- Buildings - Mining Camp.png
- Buildings - Monastery.png
- Buildings - Siege Workshop.png
- Buildings - Stable.png
- Buildings - Towers.png
- Miscellaneous - Building Icons.png
- Miscellaneous - Cursors.png
- Miscellaneous - Technology Icons.png
- Miscellaneous - Unit Icons.png
- Scenario Objects - Trade Workshop.png

### Completed Extractions
- **Cursors**: 18 sprites extracted to `images/extracted/cursors/`
  - Ready to move to `assets/sprites_extracted/cursors/`
  - cursor_017 (flag) was manually extracted

### TODO
- Move cursors to assets when approved
- Extract building sheets (Archery Range, Stable, Market, Farm)
- Extract unit sheets (not in downloaded set - need to find on Spriters Resource)
- Create MANIFEST.md in assets/sprites_extracted/

## Building Sheets - Expected Complexity

Building sprite sheets contain multiple variants:
- **Ages**: Dark, Feudal, Castle, Imperial (different looks)
- **Colors**: Blue, Red, Yellow, etc. (player colors)
- **States**: Construction, Normal, Destroyed

Will need to:
1. Extract all variants
2. Organize by building name, then variant
3. Decide which variant to use (probably Feudal age, Blue color for now)
4. Document the mapping in MANIFEST.md

## Questions to Resolve

1. **Player colors**: Use pre-colored sprites or apply tint at runtime?
   - Current game uses modulate tint on sprites
   - Could extract Blue variants and let the game tint them

2. **Ages**: Extract all ages or just one?
   - Game currently doesn't have age progression
   - Could extract all and store for future phases

3. **Unit sprites**: Where are they?
   - Cursors and Buildings found on Spriters Resource
   - Need to locate unit sprite sheets
