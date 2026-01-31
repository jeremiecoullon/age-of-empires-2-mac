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


def find_sprites(mask: np.ndarray) -> list[tuple[int, int, int, int]]:
    """
    Find connected components in the mask and return their bounding boxes.

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

        width = x_max - x_min + 1
        height = y_max - y_min + 1

        # Filter out tiny noise (less than 5x5 pixels)
        if width >= 5 and height >= 5:
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
) -> list[Path]:
    """
    Extract all sprites from an image and save them to output directory.

    Returns list of saved file paths.
    """
    print(f"Loading: {input_path}")
    img = load_image(input_path)
    print(f"Image size: {img.width}x{img.height}")

    print(f"Creating mask (filter_dark={filter_dark}, filter_white=True)...")
    # Always filter white for masking (grid lines) but not for sprite extraction
    mask = create_mask(img, filter_dark=filter_dark, filter_white=True)

    print("Finding sprites...")
    bboxes = find_sprites(mask)
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

    args = parser.parse_args()

    if not args.input.exists():
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    extract_sprites(
        args.input, args.output, args.prefix, filter_dark=not args.keep_dark
    )


if __name__ == "__main__":
    main()
