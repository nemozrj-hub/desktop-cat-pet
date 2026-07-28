#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Sources" / "DesktopCatPet" / "Resources"
SPRITE_PATH = RESOURCES / "cat_desktop_pet_sprite_sheet.png"
RAW_SPRITE_PATH = RESOURCES / "cat_desktop_pet_sprite_sheet.raw.png"
JSON_PATH = RESOURCES / "cat_desktop_pet_sprite_sheet.json"


def largest_alpha_component_mask(crop: Image.Image, threshold: int = 10) -> Image.Image:
    alpha = crop.getchannel("A")
    width, height = alpha.size
    pixels = alpha.load()
    seen = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []

    for y in range(height):
        for x in range(width):
            index = y * width + x
            if seen[index] or pixels[x, y] <= threshold:
                continue

            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen[index] = 1
            component: list[tuple[int, int]] = []

            while queue:
                cx, cy = queue.pop()
                component.append((cx, cy))

                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < width and 0 <= ny < height:
                        next_index = ny * width + nx
                        if not seen[next_index] and pixels[nx, ny] > threshold:
                            seen[next_index] = 1
                            queue.append((nx, ny))

            components.append(component)

    mask = Image.new("L", alpha.size, 0)
    if not components:
        return mask

    largest = max(components, key=len)
    mask_pixels = mask.load()
    for x, y in largest:
        mask_pixels[x, y] = alpha.getpixel((x, y))
    return mask


def main() -> None:
    if not RAW_SPRITE_PATH.exists():
        shutil.copy2(SPRITE_PATH, RAW_SPRITE_PATH)

    source = Image.open(RAW_SPRITE_PATH).convert("RGBA")
    atlas = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    cleaned = Image.new("RGBA", source.size, (0, 0, 0, 0))

    for animation in atlas["animations"].values():
        for frame in animation["frames"]:
            x, y, w, h = (frame[key] for key in ("x", "y", "w", "h"))
            crop = source.crop((x, y, x + w, y + h)).convert("RGBA")
            mask = largest_alpha_component_mask(crop)
            crop.putalpha(mask)
            cleaned.alpha_composite(crop, (x, y))

    cleaned.save(SPRITE_PATH)


if __name__ == "__main__":
    main()
