#!/usr/bin/env python3
"""
Sprite Sheet Extractor

Extracts individual sprites from sprite sheets that use magenta (#FF00FF)
as the transparency/background color.

Usage:
    python extract.py <input_image> <output_dir>

Example:
    python extract.py "../images/extra-sprites/PC _ Computer - Age of Empires II - Miscellaneous - Cursors.png" output/cursors
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


# Magenta background color used in sprite sheets
MAGENTA = (255, 0, 255)


def load_image(path: Path) -> Image.Image:
    """Load image and convert to RGBA."""
    img = Image.open(path)
    return img.convert("RGBA")


def create_mask(
    img: Image.Image, filter_dark: bool = True, filter_white: bool = True
) -> np.ndarray:
    """
    Create a binary mask where True = sprite pixel.

    Filters out:
    - Magenta (#FF00FF) - the transparency color
    - Dark pixels (black grid lines, text labels) if filter_dark=True
    - White pixels (white grid lines) if filter_white=True
    """
    data = np.array(img)

    # Check RGB channels (ignore alpha)
    r, g, b = data[:, :, 0], data[:, :, 1], data[:, :, 2]

    # Pixel is magenta (background)
    is_magenta = (r > 250) & (g < 5) & (b > 250)

    is_background = is_magenta

    # Pixel is dark (grid lines, text) - all channels below threshold
    if filter_dark:
        dark_threshold = 50
        is_dark = (r < dark_threshold) & (g < dark_threshold) & (b < dark_threshold)
        is_background = is_background | is_dark

    # Pixel is white (grid lines) - all channels above threshold
    if filter_white:
        white_threshold = 250
        is_white = (r > white_threshold) & (g > white_threshold) & (b > white_threshold)
        is_background = is_background | is_white

    return ~is_background


def find_grid_lines(img: Image.Image, threshold: int = 250) -> tuple[list[int], list[int]]:
    """
    Find white grid lines in the image.

    Returns (horizontal_lines, vertical_lines) as lists of y and x coordinates.
    """
    data = np.array(img)
    r, g, b = data[:, :, 0], data[:, :, 1], data[:, :, 2]

    # White pixels
    is_white = (r > threshold) & (g > threshold) & (b > threshold)

    # A row is a horizontal line if most of it is white
    h, w = is_white.shape
    horizontal_lines = []
    for y in range(h):
        white_ratio = np.sum(is_white[y, :]) / w
        if white_ratio > 0.8:  # 80% white = grid line
            horizontal_lines.append(y)

    # A column is a vertical line if most of it is white
    vertical_lines = []
    for x in range(w):
        white_ratio = np.sum(is_white[:, x]) / h
        if white_ratio > 0.8:
            vertical_lines.append(x)

    # Collapse consecutive lines into single positions (take middle)
    def collapse_consecutive(lines: list[int]) -> list[int]:
        if not lines:
            return []
        result = []
        start = lines[0]
        prev = lines[0]
        for line in lines[1:]:
            if line > prev + 1:  # Gap found
                result.append((start + prev) // 2)
                start = line
            prev = line
        result.append((start + prev) // 2)
        return result

    return collapse_consecutive(horizontal_lines), collapse_consecutive(vertical_lines)


def find_cells_from_grid(
    img: Image.Image,
    horizontal_lines: list[int],
    vertical_lines: list[int],
    grid_line_width: int = 2,
) -> list[tuple[int, int, int, int]]:
    """
    Given grid lines, return the bounding boxes of all cells.

    Args:
        grid_line_width: Width of grid lines to skip (offset from detected line position)

    Returns list of (x, y, width, height) tuples.
    """
    h, w = img.height, img.width

    # Add image boundaries if not already there
    y_boundaries = [0] + horizontal_lines + [h]
    x_boundaries = [0] + vertical_lines + [w]

    cells = []
    for i in range(len(y_boundaries) - 1):
        for j in range(len(x_boundaries) - 1):
            x1, x2 = x_boundaries[j], x_boundaries[j + 1]
            y1, y2 = y_boundaries[i], y_boundaries[i + 1]

            # Offset to skip grid lines (but not at image edges)
            if x1 > 0:
                x1 += grid_line_width
            if y1 > 0:
                y1 += grid_line_width
            if x2 < w:
                x2 -= grid_line_width
            if y2 < h:
                y2 -= grid_line_width

            # Skip very thin cells (grid line artifacts)
            if x2 - x1 < 10 or y2 - y1 < 10:
                continue

            cells.append((x1, y1, x2 - x1, y2 - y1))

    return cells


def crop_to_content(
    img: Image.Image, bbox: tuple[int, int, int, int], margin: int = 2
) -> tuple[int, int, int, int] | None:
    """
    Given a cell bounding box, find the actual sprite content within it.
    Returns a tighter bounding box around the non-background pixels.

    Uses a two-pass approach:
    1. Find bounds using non-magenta pixels (includes white sprite content)
    2. Trim edge rows/columns that are mostly white (grid line remnants)
    """
    x, y, w, h = bbox

    # Crop the cell
    cell = img.crop((x, y, x + w, y + h))
    data = np.array(cell)

    r, g, b = data[:, :, 0], data[:, :, 1], data[:, :, 2]

    is_magenta = (r > 250) & (g < 5) & (b > 250)
    is_white = (r > 250) & (g > 250) & (b > 250)

    # First pass: find non-magenta content bounds
    is_content = ~is_magenta
    rows = np.any(is_content, axis=1)
    cols = np.any(is_content, axis=0)

    if not np.any(rows) or not np.any(cols):
        return None  # Empty cell

    y_min, y_max = np.where(rows)[0][[0, -1]]
    x_min, x_max = np.where(cols)[0][[0, -1]]

    # Second pass: trim edge rows that are mostly white (>80% white = grid line remnant)
    # Check from top
    while y_min < y_max:
        row = data[y_min, x_min : x_max + 1]
        white_ratio = np.sum(is_white[y_min, x_min : x_max + 1]) / (x_max - x_min + 1)
        if white_ratio > 0.8:
            y_min += 1
        else:
            break

    # Check from bottom
    while y_max > y_min:
        white_ratio = np.sum(is_white[y_max, x_min : x_max + 1]) / (x_max - x_min + 1)
        if white_ratio > 0.8:
            y_max -= 1
        else:
            break

    # Check from left
    while x_min < x_max:
        white_ratio = np.sum(is_white[y_min : y_max + 1, x_min]) / (y_max - y_min + 1)
        if white_ratio > 0.8:
            x_min += 1
        else:
            break

    # Check from right
    while x_max > x_min:
        white_ratio = np.sum(is_white[y_min : y_max + 1, x_max]) / (y_max - y_min + 1)
        if white_ratio > 0.8:
            x_max -= 1
        else:
            break

    # Add margin
    x_min = max(0, x_min - margin)
    y_min = max(0, y_min - margin)
    x_max = min(w - 1, x_max + margin)
    y_max = min(h - 1, y_max + margin)

    # Convert back to image coordinates
    return (x + x_min, y + y_min, x_max - x_min + 1, y_max - y_min + 1)


def find_sprites(
    mask: np.ndarray,
    margin: int = 0,
    min_size: int = 5,
    image_size: tuple[int, int] | None = None,
) -> list[tuple[int, int, int, int]]:
    """
    Find connected components in the mask and return their bounding boxes.

    Args:
        mask: Binary mask where True = sprite pixel
        margin: Pixels to add around each bounding box (to avoid cutting off edges)
        min_size: Minimum width/height to not be considered noise (applied BEFORE margin)
        image_size: (width, height) to clamp bounding boxes to image bounds

    Returns list of (x, y, width, height) tuples.
    """
    # Label connected components
    labeled, num_features = ndimage.label(mask)

    # Find bounding box for each component
    bboxes = []
    for i in range(1, num_features + 1):
        # Find where this label exists
        rows = np.any(labeled == i, axis=1)
        cols = np.any(labeled == i, axis=0)

        y_min, y_max = np.where(rows)[0][[0, -1]]
        x_min, x_max = np.where(cols)[0][[0, -1]]

        # Calculate original size (before margin) for noise filtering
        orig_width = x_max - x_min + 1
        orig_height = y_max - y_min + 1

        # Filter out tiny noise based on original size
        if orig_width < min_size or orig_height < min_size:
            continue

        # Add margin
        x_min = max(0, x_min - margin)
        y_min = max(0, y_min - margin)
        x_max = x_max + margin
        y_max = y_max + margin

        # Clamp to image bounds if provided
        if image_size:
            img_w, img_h = image_size
            x_max = min(x_max, img_w - 1)
            y_max = min(y_max, img_h - 1)

        width = x_max - x_min + 1
        height = y_max - y_min + 1

        bboxes.append((x_min, y_min, width, height))

    # Sort by position: top-to-bottom, then left-to-right
    bboxes.sort(key=lambda b: (b[1] // 50, b[0]))  # Group rows within 50px

    return bboxes


def extract_sprite(
    img: Image.Image,
    bbox: tuple[int, int, int, int],
    filter_dark: bool = True,
    filter_white: bool = False,  # Usually don't want to remove white from actual sprites
) -> Image.Image:
    """
    Extract a sprite from the image at the given bounding box.
    Converts magenta (and optionally dark/white) pixels to transparent.

    Note: filter_white defaults to False for extraction since sprites may
    contain white pixels (highlights, etc). It's mainly used for masking.
    """
    x, y, w, h = bbox

    # Crop the region
    sprite = img.crop((x, y, x + w, y + h))

    # Convert background colors to transparent
    data = np.array(sprite)
    r, g, b, a = data[:, :, 0], data[:, :, 1], data[:, :, 2], data[:, :, 3]

    # Magenta = transparent
    is_magenta = (r > 250) & (g < 5) & (b > 250)
    is_background = is_magenta

    if filter_dark:
        # Dark pixels (grid lines, labels) = transparent
        dark_threshold = 50
        is_dark = (r < dark_threshold) & (g < dark_threshold) & (b < dark_threshold)
        is_background = is_background | is_dark

    if filter_white:
        white_threshold = 250
        is_white = (r > white_threshold) & (g > white_threshold) & (b > white_threshold)
        is_background = is_background | is_white

    data[:, :, 3] = np.where(is_background, 0, a)

    return Image.fromarray(data)


def extract_sprites(
    input_path: Path,
    output_dir: Path,
    prefix: str = "sprite",
    filter_dark: bool = True,
    margin: int = 2,
    min_size: int = 10,
) -> list[Path]:
    """
    Extract all sprites from an image using connected component detection.

    Returns list of saved file paths.
    """
    print(f"Loading: {input_path}")
    img = load_image(input_path)
    print(f"Image size: {img.width}x{img.height}")

    print(f"Creating mask (filter_dark={filter_dark}, filter_white=True)...")
    # Always filter white for masking (grid lines) but not for sprite extraction
    mask = create_mask(img, filter_dark=filter_dark, filter_white=True)

    print(f"Finding sprites (margin={margin}, min_size={min_size})...")
    bboxes = find_sprites(
        mask, margin=margin, min_size=min_size, image_size=(img.width, img.height)
    )
    print(f"Found {len(bboxes)} sprites")

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Extract and save each sprite
    saved_files = []
    for i, bbox in enumerate(bboxes):
        sprite = extract_sprite(img, bbox, filter_dark=filter_dark)

        filename = f"{prefix}_{i:03d}.png"
        output_path = output_dir / filename
        sprite.save(output_path, "PNG")

        x, y, w, h = bbox
        print(f"  {filename}: {w}x{h} at ({x}, {y})")
        saved_files.append(output_path)

    print(f"\nSaved {len(saved_files)} sprites to {output_dir}")
    return saved_files


def extract_sprites_grid(
    input_path: Path,
    output_dir: Path,
    prefix: str = "sprite",
    filter_dark: bool = True,
    margin: int = 2,
) -> list[Path]:
    """
    Extract sprites using grid-based detection.

    Finds white grid lines, splits into cells, then extracts the content
    from each cell. Better for sprite sheets with clear grid layouts where
    sprites may have disconnected parts that should stay together.

    Returns list of saved file paths.
    """
    print(f"Loading: {input_path}")
    img = load_image(input_path)
    print(f"Image size: {img.width}x{img.height}")

    print("Detecting grid lines...")
    h_lines, v_lines = find_grid_lines(img)
    print(f"  Found {len(h_lines)} horizontal lines: {h_lines}")
    print(f"  Found {len(v_lines)} vertical lines: {v_lines}")

    print("Finding cells...")
    cells = find_cells_from_grid(img, h_lines, v_lines)
    print(f"  Found {len(cells)} cells")

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Extract content from each cell
    saved_files = []
    sprite_num = 0
    for cell in cells:
        content_bbox = crop_to_content(img, cell, margin=margin)
        if content_bbox is None:
            continue  # Empty cell

        sprite = extract_sprite(img, content_bbox, filter_dark=filter_dark)

        filename = f"{prefix}_{sprite_num:03d}.png"
        output_path = output_dir / filename
        sprite.save(output_path, "PNG")

        x, y, w, h = content_bbox
        print(f"  {filename}: {w}x{h} at ({x}, {y})")
        saved_files.append(output_path)
        sprite_num += 1

    print(f"\nSaved {len(saved_files)} sprites to {output_dir}")
    return saved_files


def main():
    parser = argparse.ArgumentParser(
        description="Extract sprites from a sprite sheet with magenta background"
    )
    parser.add_argument("input", type=Path, help="Input sprite sheet image")
    parser.add_argument("output", type=Path, help="Output directory for extracted sprites")
    parser.add_argument(
        "--prefix",
        default="sprite",
        help="Prefix for output filenames (default: sprite)",
    )
    parser.add_argument(
        "--keep-dark",
        action="store_true",
        help="Keep dark pixels (don't filter grid lines/labels)",
    )
    parser.add_argument(
        "--margin",
        type=int,
        default=2,
        help="Pixels to add around each sprite bounding box (default: 2)",
    )
    parser.add_argument(
        "--min-size",
        type=int,
        default=10,
        help="Minimum sprite size in pixels, smaller = noise (default: 10)",
    )
    parser.add_argument(
        "--grid",
        action="store_true",
        help="Use grid-based detection (better for sheets with clear grid lines)",
    )

    args = parser.parse_args()

    if not args.input.exists():
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    if args.grid:
        extract_sprites_grid(
            args.input,
            args.output,
            args.prefix,
            filter_dark=not args.keep_dark,
            margin=args.margin,
        )
    else:
        extract_sprites(
            args.input,
            args.output,
            args.prefix,
            filter_dark=not args.keep_dark,
            margin=args.margin,
            min_size=args.min_size,
        )


if __name__ == "__main__":
    main()
