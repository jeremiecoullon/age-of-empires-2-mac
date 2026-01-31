#!/usr/bin/env python3
"""
Manual sprite extraction for edge cases that the grid/auto detection can't handle.

Usage:
    python manual_extract.py <input_image> <output_file> --crop x1 y1 x2 y2 [--remove-white]

Example (cursor_017 flag):
    python manual_extract.py \
        "../../images/extra-sprites/PC _ Computer - Age of Empires II - Miscellaneous - Cursors.png" \
        "../../images/extracted/cursors/cursor_017.png" \
        --crop 553 75 622 173 \
        --remove-white
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def manual_extract(
    input_path: Path,
    output_path: Path,
    crop_box: tuple[int, int, int, int],
    remove_white: bool = False,
) -> None:
    """
    Extract a sprite from a specific region of an image.

    Args:
        input_path: Source sprite sheet
        output_path: Where to save the extracted sprite
        crop_box: (x1, y1, x2, y2) region to extract
        remove_white: Also make white pixels transparent (for grid line remnants)
    """
    img = Image.open(input_path).convert("RGBA")

    x1, y1, x2, y2 = crop_box
    sprite = img.crop((x1, y1, x2, y2))
    data = np.array(sprite)

    r, g, b, a = data[:, :, 0], data[:, :, 1], data[:, :, 2], data[:, :, 3]

    # Always remove magenta
    is_magenta = (r > 250) & (g < 5) & (b > 250)
    is_background = is_magenta

    # Optionally remove white (grid lines)
    if remove_white:
        is_white = (r > 250) & (g > 250) & (b > 250)
        is_background = is_background | is_white

    data[:, :, 3] = np.where(is_background, 0, a)

    result = Image.fromarray(data)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    result.save(output_path)

    print(f"Saved: {output_path} ({result.size[0]}x{result.size[1]})")


def main():
    parser = argparse.ArgumentParser(
        description="Manually extract a sprite from a specific region"
    )
    parser.add_argument("input", type=Path, help="Input sprite sheet")
    parser.add_argument("output", type=Path, help="Output sprite file")
    parser.add_argument(
        "--crop",
        type=int,
        nargs=4,
        metavar=("X1", "Y1", "X2", "Y2"),
        required=True,
        help="Crop region (x1 y1 x2 y2)",
    )
    parser.add_argument(
        "--remove-white",
        action="store_true",
        help="Also make white pixels transparent (for grid line remnants)",
    )

    args = parser.parse_args()

    if not args.input.exists():
        print(f"Error: Input file not found: {args.input}")
        return 1

    manual_extract(
        args.input,
        args.output,
        tuple(args.crop),
        remove_white=args.remove_white,
    )
    return 0


if __name__ == "__main__":
    exit(main())
