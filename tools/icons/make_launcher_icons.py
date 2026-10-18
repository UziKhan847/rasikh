"""Builds every launcher icon from assets/brand/icon-glyph.png — the design's
icon 1a: the glyph in cream #F2EEE4 on emerald #0F3B32.
Run from the repo root:  python3 tools/icons/make_launcher_icons.py"""
import json
from PIL import Image, ImageDraw

EMERALD = (15, 59, 50, 255)
CREAM = (242, 238, 228, 255)
GLYPH = Image.open('assets/brand/icon-glyph.png').convert('RGBA')
MASK = GLYPH.split()[3]  # the glyph is an alpha mask


def glyph(size, colour, scale=1.0):
    """The glyph alone on transparent, [scale] of its own 512 layout."""
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    g = int(size * scale)
    m = MASK.resize((g, g), Image.LANCZOS)
    solid = Image.new('RGBA', (g, g), colour)
    off = (size - g) // 2
    out.paste(solid, (off, off), m)
    return out


def full(size, radius=0.0, scale=1.0):
    """Emerald square (optionally rounded) with the cream glyph."""
    big = size * 4
    bg = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((0, 0, big - 1, big - 1), radius=int(big * radius), fill=EMERALD)
    bg.alpha_composite(glyph(big, CREAM, scale))
    return bg.resize((size, size), Image.LANCZOS)


def save(img, path, rgb=False):
    (img.convert('RGB') if rgb else img).save(path)
    print(path, img.size)


# sources kept with the brand art
save(full(512, radius=.22), 'assets/apk_icons/app_launcher_icon.png')
save(glyph(512, CREAM), 'assets/apk_icons/adaptive_icon_foreground.png')
save(Image.new('RGBA', (512, 512), EMERALD), 'assets/apk_icons/adaptive_icon_background.png')
save(glyph(512, (0, 0, 0, 255)), 'assets/apk_icons/adaptive_icon_monochrome.png')

# Android: adaptive layers (108dp) and the legacy launcher (48dp)
res = 'android/app/src/main/res'
for name, k in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
    a = int(108 * k)
    save(glyph(a, CREAM), f'{res}/drawable-{name}/ic_launcher_foreground.png')
    save(Image.new('RGBA', (a, a), EMERALD), f'{res}/drawable-{name}/ic_launcher_background.png')
    save(glyph(a, (0, 0, 0, 255)), f'{res}/drawable-{name}/ic_launcher_monochrome.png')
    save(full(int(48 * k), radius=.22), f'{res}/mipmap-{name}/ic_launcher.png')

# iOS: full-bleed squares, no alpha (the system rounds them)
ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for img in json.load(open(f'{ios}/Contents.json'))['images']:
    px = round(float(img['size'].split('x')[0]) * int(img['scale'][0]))
    save(full(px), f"{ios}/{img['filename']}", rgb=True)

# macOS: rounded squares with a small margin, as macOS icons are drawn
mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
for px in [16, 32, 64, 128, 256, 512, 1024]:
    big = full(px, radius=.22)
    pad = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    inner = big.resize((int(px * .82), int(px * .82)), Image.LANCZOS)
    pad.alpha_composite(inner, ((px - inner.width) // 2, (px - inner.height) // 2))
    save(pad, f'{mac}/app_icon_{px}.png')

# Windows
full(256, radius=.22).save('windows/runner/resources/app_icon.ico',
                           sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print('windows/runner/resources/app_icon.ico')

# Web: rounded icons, and full-bleed maskable ones with the glyph in the safe zone
save(full(192, radius=.22), 'web/icons/Icon-192.png')
save(full(512, radius=.22), 'web/icons/Icon-512.png')
save(full(192, scale=.8), 'web/icons/Icon-maskable-192.png')
save(full(512, scale=.8), 'web/icons/Icon-maskable-512.png')
save(full(32, radius=.22), 'web/favicon.png')
