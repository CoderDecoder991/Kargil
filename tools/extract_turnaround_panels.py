"""Split the user-provided 4x2 turnarounds into alpha cutouts for the sprite rig."""

from pathlib import Path
from collections import deque
import json
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/reference"
DESTINATION = ROOT / "assets/Characters/generated_turnaround"
PANEL_WIDTH, PANEL_HEIGHT = 384, 512
CROP = (4, 3, 380, 509)


def remove_studio_background(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, alpha = pixels[x, y]
            brightness = (r + g + b) / 3.0
            chroma = max(r, g, b) - min(r, g, b)
            if brightness > 138 and chroma < 38:
                t = max(0.0, min(1.0, (brightness - 138.0) / 54.0))
                t = t * t * (3.0 - 2.0 * t)
                pixels[x, y] = (r, g, b, round(255 * (1.0 - t)))
    return image


def remove_dark_warm_background(image: Image.Image) -> Image.Image:
    """Flood-fill only the connected warm studio backdrop, preserving dark kit."""
    image = image.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    # ImageGen sometimes supplies true alpha despite a visible dark preview.
    # Preserve that matte exactly; chroma removal is only for opaque turnarounds.
    corners = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    if all(pixels[x, y][3] < 16 for x, y in corners):
        return image
    visited = bytearray(width * height)
    queue = deque()

    def is_backdrop(x: int, y: int) -> bool:
        r, g, b, alpha = pixels[x, y]
        if alpha < 16:
            return False
        return r < 125 and g < 120 and b < 105 and r >= g - 2 and g >= b + 7

    for x in range(width):
        for y in (0, height - 1):
            index = y * width + x
            if not visited[index] and is_backdrop(x, y):
                visited[index] = 1
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            index = y * width + x
            if not visited[index] and is_backdrop(x, y):
                visited[index] = 1
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        r, g, b, _ = pixels[x, y]
        # A narrow colour transition preserves dark rifles and boots while
        # softening only the warm grey studio edge into the alpha channel.
        edge = g - r
        alpha = 0 if edge <= -1 else min(255, round((edge + 1) * 42))
        pixels[x, y] = (r, g, b, alpha)
        for ny in range(max(0, y - 1), min(height, y + 2)):
            for nx in range(max(0, x - 1), min(width, x + 2)):
                index = ny * width + nx
                if not visited[index] and is_backdrop(nx, ny):
                    visited[index] = 1
                    queue.append((nx, ny))
    return image


def extract_walk_cycle(source: Path, pose: str) -> None:
    sheet = Image.open(source).convert("RGBA")
    columns, rows = 4, 8
    cell_w, cell_h = sheet.width // columns, sheet.height // rows
    cells = {}
    global_scale = 0.0
    for view in range(rows):
        for frame in range(columns):
            cell = sheet.crop((frame * cell_w, view * cell_h, (frame + 1) * cell_w, (view + 1) * cell_h))
            cell = remove_dark_warm_background(cell)
            alpha = cell.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.3))
            cell.putalpha(alpha)
            bounds = cell.getchannel("A").getbbox()
            if bounds is None:
                continue
            cropped = cell.crop(bounds)
            cells[(view, frame)] = (cropped, bounds)
            global_scale = max(global_scale, 468.0 / cropped.height)

    for (view, frame), (cutout, _) in cells.items():
        # Keep one uniform scale for all views and frames; only the natural
        # stepping pose changes, never the sprite's apparent character size.
        resized = cutout.resize((round(cutout.width * global_scale), round(cutout.height * global_scale)), Image.Resampling.LANCZOS)
        output = Image.new("RGBA", (640, 506), (0, 0, 0, 0))
        x = (output.width - resized.width) // 2
        y = output.height - resized.height
        output.alpha_composite(resized, (x, y))
        output.save(DESTINATION / f"soldier_walk_{pose}_{view}_{frame}.png", optimize=True)

    # Walking poses naturally spread the legs. Compensate horizontal spread
    # against the matching idle turnaround so the character does not look as
    # though it grows when the walk cycle starts. Use one scale per view/pose,
    # based on the widest of its four frames, so no stride phase can grow wider.
    for view in range(rows):
        still = Image.open(DESTINATION / f"soldier_{pose}_{view}.png").convert("RGBA")
        still_alpha = still.getchannel("A").point(lambda value: 255 if value >= 48 else 0)
        still_bounds = still_alpha.getbbox()
        still_width = still_bounds[2] - still_bounds[0] if still_bounds else 1
        still_height = still_bounds[3] - still_bounds[1] if still_bounds else 1
        cycle_width = 1
        cycle_height = 1
        for frame in range(columns):
            walk = Image.open(DESTINATION / f"soldier_walk_{pose}_{view}_{frame}.png").convert("RGBA")
            walk_alpha = walk.getchannel("A").point(lambda value: 255 if value >= 48 else 0)
            walk_bounds = walk_alpha.getbbox()
            if walk_bounds:
                cycle_width = max(cycle_width, walk_bounds[2] - walk_bounds[0])
                cycle_height = max(cycle_height, walk_bounds[3] - walk_bounds[1])
        WIDTH_SCALES[f"{pose}_{view}"] = {
            "x": round(min(1.0, still_width / cycle_width), 4),
            "y": round(min(1.0, still_height / cycle_height), 4),
        }


WIDTH_SCALES: dict[str, float] = {}


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    sheets = {
        "high": "rifle_high_ready_turnaround.png",
        "low": "rifle_low_ready_turnaround.png",
        "crouch_high": "rifle_crouch_high_turnaround.png",
        "crouch_low": "rifle_crouch_low_turnaround.png",
    }
    for pose, filename in sheets.items():
        sheet = Image.open(SOURCE / filename).convert("RGBA")
        for view in range(8):
            col, row = view % 4, view // 4
            left = col * PANEL_WIDTH
            top = row * PANEL_HEIGHT
            panel = sheet.crop((left + CROP[0], top + CROP[1], left + CROP[2], top + CROP[3]))
            panel = remove_studio_background(panel)
            panel.save(DESTINATION / f"soldier_{pose}_{view}.png", optimize=True)
    walk_sheets = {
        "low": "rifle_walk_cycle_turnaround.png",
        "high": "rifle_walk_high_cycle_turnaround.png",
        "crouch_low": "rifle_crouch_walk_cycle_turnaround.png",
        "crouch_high": "rifle_crouch_walk_high_cycle_turnaround.png",
    }
    for pose, filename in walk_sheets.items():
        extract_walk_cycle(SOURCE / filename, pose)
    (DESTINATION / "walk_width_scales.json").write_text(json.dumps(WIDTH_SCALES, indent=2), encoding="utf-8")
    print(f"Extracted 160 alpha cutouts to {DESTINATION}")


if __name__ == "__main__":
    main()
