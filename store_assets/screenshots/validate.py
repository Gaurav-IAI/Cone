"""Validates the Play Store screenshots and writes manifest.json.

Run from the project root:  python store_assets/screenshots/validate.py
"""
import hashlib
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MAX_BYTES = 8 * 1024 * 1024

# Google Play Console limits per category: (min side, max side).
RULES = {
    'phone': (320, 3840),
    'tablet_7_inch': (320, 3840),
    'tablet_10_inch': (1080, 7680),
}

FEATURES = {
    '01': 'Dashboard — profile, role badge, pass and coupon shortcuts (Presenter)',
    '02': 'Virtual conference pass with QR code (encodes only the pass ID)',
    '03': 'Digital meal coupons — breakfast, lunch, dinner, each with its own QR and live status',
    '04': 'Conference programme — sessions by day, own presentation highlighted',
    '05': 'Personal profile — registration details (email blurred for publication)',
    '06': 'Speaker experience — talk title, session, time, venue and summary',
    '07': 'Organiser dashboard — registrations per role, meals served, People, Meal desk',
    '08': 'Volunteer meal desk — coupon checked and shown Valid with "Done — mark as served"',
}

entries, problems, hashes = [], [], {}
for category, (lo, hi) in RULES.items():
    folder = os.path.join(HERE, category)
    files = sorted(f for f in os.listdir(folder) if f.lower().endswith(('.png', '.jpg', '.jpeg')))
    if not 2 <= len(files) <= 8:
        problems.append(f'{category}: {len(files)} files (Play allows 2-8)')
    for name in files:
        path = os.path.join(folder, name)
        size = os.path.getsize(path)
        with Image.open(path) as im:
            im.verify()  # structural check
        with Image.open(path) as im:
            im.load()  # full decode
            w, h, fmt = im.width, im.height, im.format
        digest = hashlib.sha256(open(path, 'rb').read()).hexdigest()
        checks = {
            'opens': True,
            'format_png_or_jpeg': fmt in ('PNG', 'JPEG'),
            'under_8mb': size <= MAX_BYTES,
            'dimensions_in_range': lo <= w <= hi and lo <= h <= hi,
            'aspect_at_most_2_to_1': max(w, h) <= 2 * min(w, h),
            'portrait': h > w,
            'unique': digest not in hashes,
        }
        if not checks['unique']:
            problems.append(f'{category}/{name} duplicates {hashes[digest]}')
        hashes.setdefault(digest, f'{category}/{name}')
        status = 'PASS' if all(checks.values()) else 'FAIL'
        if status == 'FAIL':
            problems.append(f'{category}/{name}: ' + ', '.join(k for k, v in checks.items() if not v))
        entries.append({
            'file': f'{category}/{name}',
            'category': category,
            'width': w,
            'height': h,
            'format': fmt,
            'bytes': size,
            'feature': FEATURES.get(name[:2], ''),
            'checks': checks,
            'status': status,
        })

manifest = {'files': entries, 'problems': problems, 'all_passed': not problems}
with open(os.path.join(HERE, 'manifest.json'), 'w', encoding='utf-8') as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)
for e in entries:
    print(f"{e['status']}  {e['file']:<62} {e['width']}x{e['height']} {e['format']} {e['bytes']/1024:7.0f} KB")
print('problems:', problems or 'none')
sys.exit(1 if problems else 0)
