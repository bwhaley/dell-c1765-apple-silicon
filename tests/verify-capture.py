"""Run with scripts/run.sh active and a 'capture' file queue configured."""
from pathlib import Path
import subprocess
import re
import sys

root = Path(__file__).resolve().parents[1]
app = root / 'build/bin/dell-printer'
decoder = root / 'vendor/foo2zjs-20200505dfsg0/hbpldecode'
uri = 'ipp://localhost:8631/ipp/print/capture'
fixture = sys.argv[1] if len(sys.argv)>1 else str(root / 'build/two-page.pwg')
for mode, expected in [('color', ['1', '0']), ('monochrome', ['0', '0'])]:
    # PAPPL's file device overwrites without truncating an existing output file.
    (root / 'build/capture.hbpl').write_bytes(b'')
    subprocess.run([str(app), 'submit', '-u', uri, '-o', f'print-color-mode={mode}',
                    fixture], check=True)
    decoded = subprocess.check_output([str(decoder), str(root / 'build/capture.hbpl')], text=True)
    assert decoded.count('[Page Start]') == 2, decoded
    assert decoded.count('[Page End]') == 2, decoded
    assert re.findall(r'color = (\d+)', decoded) == expected, decoded
    assert decoded.count('papersize = Letter(4)') == 2
    (root / f'build/{mode}-verified.txt').write_text(decoded)
    print(f'PASS: {mode}, two pages, expected color planes, Letter media')
