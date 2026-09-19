#!/usr/bin/env python3
"""
FinTrack - Google Play Store Screenshot Generator
Generates high-converting, compliant 1080x1920 (16:9) Play Store screenshots
from phone mockup screenshots, complete with feature badges, typography,
and ambient glow effects.
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
from scipy import ndimage

CANVAS_WIDTH = 1080
CANVAS_HEIGHT = 1920

def get_font(weight="bold", size=48):
    font_map = {
        "extrabold": [
            "/usr/share/fonts/julietaula-montserrat-fonts/Montserrat-ExtraBold.otf",
            "/usr/share/fonts/open-sans/OpenSans-ExtraBold.ttf",
            "/usr/share/fonts/google-noto-vf/NotoSans[wght].ttf",
        ],
        "bold": [
            "/usr/share/fonts/julietaula-montserrat-fonts/Montserrat-Bold.otf",
            "/usr/share/fonts/open-sans/OpenSans-Bold.ttf",
            "/usr/share/fonts/liberation-sans-fonts/LiberationSans-Bold.ttf",
        ],
        "semibold": [
            "/usr/share/fonts/julietaula-montserrat-fonts/Montserrat-SemiBold.otf",
            "/usr/share/fonts/open-sans/OpenSans-Semibold.ttf",
            "/usr/share/fonts/google-noto-vf/NotoSans[wght].ttf",
        ],
        "medium": [
            "/usr/share/fonts/julietaula-montserrat-fonts/Montserrat-Medium.otf",
            "/usr/share/fonts/open-sans/OpenSans-Regular.ttf",
            "/usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf",
        ],
        "regular": [
            "/usr/share/fonts/julietaula-montserrat-fonts/Montserrat-Regular.otf",
            "/usr/share/fonts/open-sans/OpenSans-Regular.ttf",
            "/usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf",
        ],
    }

    candidates = font_map.get(weight, font_map["regular"])
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                pass
    return ImageFont.load_default()

def wrap_text(text, font, max_width):
    words = text.split()
    lines = []
    curr = []
    for w in words:
        test_line = " ".join(curr + [w])
        bbox = font.getbbox(test_line)
        line_w = bbox[2] - bbox[0]
        if line_w > max_width and curr:
            lines.append(" ".join(curr))
            curr = [w]
        else:
            curr.append(w)
    if curr:
        lines.append(" ".join(curr))
    return lines

def extract_phone_mockup(img_path):
    """
    Isolates the phone mockup from the white border using connected-component
    labeling so that inner white elements (like buttons or cards) are preserved.
    """
    img = Image.open(img_path).convert("RGBA")
    arr = np.array(img)
    rgb = arr[:, :, :3]
    
    # Check if border is white
    is_white = np.all(rgb > 250, axis=2)
    lbl, _ = ndimage.label(is_white)
    bg_mask = (lbl == lbl[0, 0])
    
    # Set background to transparent
    arr[bg_mask, 3] = 0
    phone_img = Image.fromarray(arr)
    
    # Find bounding box of non-transparent phone
    mask = (arr[:, :, 3] > 0)
    rows = np.any(mask, axis=1)
    cols = np.any(mask, axis=0)
    if np.any(rows) and np.any(cols):
        ymin, ymax = np.where(rows)[0][[0, -1]]
        xmin, xmax = np.where(cols)[0][[0, -1]]
        return phone_img.crop((xmin, ymin, xmax + 1, ymax + 1))
    return phone_img

def render_play_store_screenshot(
    mockup_img_path,
    output_path,
    tag,
    title,
    subtitle,
    accent_color,
    glow_color,
):
    print(f"Generating: {os.path.basename(output_path)} ...")
    
    # 1. Base Dark Canvas
    canvas = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (13, 17, 28, 255))

    # 2. Ambient Radial Glow behind Phone
    glow = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = CANVAS_WIDTH // 2, 1100
    glow_radius = 580
    for r in range(glow_radius, 0, -8):
        alpha = int(44 * (1.0 - (r / glow_radius) ** 1.3))
        glow_draw.ellipse(
            (cx - r, cy - r, cx + r, cy + r),
            fill=(glow_color[0], glow_color[1], glow_color[2], alpha),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(36))
    canvas = Image.alpha_composite(canvas, glow)
    draw = ImageDraw.Draw(canvas)

    # 3. Header: Feature Tag Pill
    f_tag = get_font("semibold", 21)
    tag_bbox = f_tag.getbbox(tag)
    tag_w = tag_bbox[2] - tag_bbox[0]
    tag_h = tag_bbox[3] - tag_bbox[1]

    tag_x = (CANVAS_WIDTH - tag_w) // 2
    tag_y = 75
    pad_h, pad_v = 22, 9

    pill_rect = (
        tag_x - pad_h,
        tag_y - pad_v,
        tag_x + tag_w + pad_h,
        tag_y + tag_h + pad_v,
    )
    draw.rounded_rectangle(
        pill_rect,
        radius=18,
        fill=(glow_color[0], glow_color[1], glow_color[2], 30),
        outline=(glow_color[0], glow_color[1], glow_color[2], 130),
        width=2,
    )
    draw.text((tag_x, tag_y - 2), tag, font=f_tag, fill=accent_color)

    # 4. Main Title
    f_title = get_font("extrabold", 52)
    title_lines = wrap_text(title, f_title, CANVAS_WIDTH - 140)

    title_y = tag_y + tag_h + pad_v + 28
    for line in title_lines:
        t_bbox = f_title.getbbox(line)
        tw = t_bbox[2] - t_bbox[0]
        tx = (CANVAS_WIDTH - tw) // 2
        draw.text((tx, title_y), line, font=f_title, fill=(255, 255, 255, 255))
        title_y += (t_bbox[3] - t_bbox[1]) + 12

    # 5. Subtitle
    f_sub = get_font("medium", 24)
    sub_lines = wrap_text(subtitle, f_sub, CANVAS_WIDTH - 160)

    sub_y = title_y + 6
    for sline in sub_lines:
        s_bbox = f_sub.getbbox(sline)
        sw = s_bbox[2] - s_bbox[0]
        sx = (CANVAS_WIDTH - sw) // 2
        draw.text((sx, sub_y), sline, font=f_sub, fill=(160, 174, 192, 255))
        sub_y += (s_bbox[3] - s_bbox[1]) + 8

    # 6. Phone Mockup Placement
    phone = extract_phone_mockup(mockup_img_path)
    
    phone_w = 724
    aspect = phone.height / phone.width
    phone_h = int(phone_w * aspect)
    
    resized_phone = phone.resize((phone_w, phone_h), Image.Resampling.LANCZOS)
    phone_x = (CANVAS_WIDTH - phone_w) // 2
    phone_y = sub_y + 32

    # Soft Drop Shadow under phone
    shadow_pad = 40
    s_layer = Image.new("RGBA", (phone_w + shadow_pad * 2, phone_h + shadow_pad * 2), (0, 0, 0, 0))
    phone_alpha = resized_phone.split()[3]
    s_layer.paste((0, 0, 0, 160), (shadow_pad, shadow_pad + 14), phone_alpha)
    s_layer = s_layer.filter(ImageFilter.GaussianBlur(28))
    canvas.paste(s_layer, (phone_x - shadow_pad, phone_y - shadow_pad), s_layer)

    # Paste phone mockup
    canvas.paste(resized_phone, (phone_x, phone_y), resized_phone)

    # Convert to 24-bit RGB (strict Google Play requirement: no alpha)
    final_rgb = canvas.convert("RGB")
    final_rgb.save(output_path, "PNG", quality=95)
    print(f" -> Completed: {output_path} ({CANVAS_WIDTH}x{CANVAS_HEIGHT})")

def main():
    base_dir = "/home/sakin/Projects/FinTrack"
    sc_dir = os.path.join(base_dir, "screenshots")
    out_dir = os.path.join(sc_dir, "play_store")
    os.makedirs(out_dir, exist_ok=True)

    configs = [
        {
            "raw": "home.PNG",
            "out": "01_dashboard.png",
            "tag": "SMART DASHBOARD",
            "title": "All Your Finances in One Place",
            "subtitle": "Real-time balance, category spending & upcoming bills",
            "accent": (255, 110, 64),
            "glow": (255, 87, 34),
        },
        {
            "raw": "add_transaction.PNG",
            "out": "02_quick_add.png",
            "tag": "LIGHTNING FAST",
            "title": "Instant Transaction Entry",
            "subtitle": "Smart quick entry, built-in keypad & auto-categorization",
            "accent": (129, 140, 248),
            "glow": (99, 102, 241),
        },
        {
            "raw": "activity.PNG",
            "out": "03_activity.png",
            "tag": "TRANSACTION HISTORY",
            "title": "Organized Activity Log",
            "subtitle": "Daily grouped transactions with search & quick filters",
            "accent": (52, 211, 153),
            "glow": (16, 185, 129),
        },
        {
            "raw": "budgets.PNG",
            "out": "04_budgets.png",
            "tag": "SMART BUDGETING",
            "title": "Safe-to-Spend & Budgets",
            "subtitle": "Know exactly what you can spend without breaking limits",
            "accent": (45, 212, 191),
            "glow": (20, 184, 166),
        },
        {
            "raw": "statistics.PNG",
            "out": "05_statistics.png",
            "tag": "VISUAL ANALYTICS",
            "title": "Deep Spending Insights",
            "subtitle": "Interactive donut breakdowns, monthly trends & cash flow",
            "accent": (96, 165, 250),
            "glow": (59, 130, 246),
        },
        {
            "raw": "splash.PNG",
            "out": "06_branding.png",
            "tag": "PERSONAL FINANCE",
            "title": "FinTrack: Master Your Money",
            "subtitle": "Simple, private, and powerful financial tracking for Android",
            "accent": (255, 110, 64),
            "glow": (255, 87, 34),
        },
    ]

    print(f"Starting Google Play screenshot generation ({len(configs)} screens)...")
    for cfg in configs:
        raw_path = os.path.join(sc_dir, cfg["raw"])
        out_path = os.path.join(out_dir, cfg["out"])
        if not os.path.exists(raw_path):
            print(f"Warning: Mockup screenshot not found: {raw_path}")
            continue
        render_play_store_screenshot(
            raw_path,
            out_path,
            cfg["tag"],
            cfg["title"],
            cfg["subtitle"],
            cfg["accent"],
            cfg["glow"],
        )

    # Clean up obsolete files if present
    for obsolete in ["06_settings.png", "07_branding.png", "01_dashboard_full.png"]:
        obsolete_p = os.path.join(out_dir, obsolete)
        if os.path.exists(obsolete_p):
            os.remove(obsolete_p)

    print("\nAll Google Play Store screenshots generated successfully!")
    print(f"Location: {out_dir}")

if __name__ == "__main__":
    main()
