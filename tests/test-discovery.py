"""Exercise installer discovery/selection without contacting the network."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        fake = self.folder / 'ippfind'
        fake.write_text('''#!/bin/sh
printf '%s\\n' "$@" > "$DISCOVERY_CALL"
printf '%s' "$DISCOVERY_OUTPUT"
exit "$DISCOVERY_STATUS"
''')
        fake.chmod(0o755)
        self.env = dict(os.environ, PATH=f'{self.folder}:/usr/bin:/bin',
                        DISCOVERY_CALL=str(self.folder / 'call'),
                        DISCOVERY_OUTPUT='', DISCOVERY_STATUS='0')

    def select(self, output='', reply='', host=None, status=0):
        self.env.update(DISCOVERY_OUTPUT=output, DISCOVERY_STATUS=str(status))
        args = ['sh', str(ROOT / 'scripts/select-printer.sh')]
        if host is not None:
            args.append(host)
        return subprocess.run(args, input=reply, text=True, capture_output=True,
                              env=self.env, timeout=5)

    def test_single_match_needs_no_input(self):
        result = self.select('DELL-EXAMPLE.local.\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'dell-example.local\n')
        args = (self.folder / 'call').read_text().splitlines()
        self.assertIn('_pdl-datastream._tcp', args)
        self.assertIn('--remote', args)
        self.assertEqual(args[args.index('--port') + 1], '9100')
        self.assertIn('C1765nfw', args[args.index('--txt-ty') + 1])

    def test_duplicate_advertisements_are_one_printer(self):
        result = self.select('DELL-A.local.\ndell-a.local\ndell-a.local\n')
        self.assertEqual(result.stdout, 'dell-a.local\n')
        self.assertNotIn('Choose', result.stderr)

    def test_multiple_requires_choice(self):
        result = self.select('dell-b.local\ndell-a.local\n', reply='2\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'dell-b.local\n')
        self.assertIn('Multiple', result.stderr)

    def test_invalid_or_missing_choice_cancels(self):
        for reply in ['', '\n', '0\n', '3\n', 'x\n']:
            with self.subTest(reply=reply):
                result = self.select('dell-a.local\ndell-b.local\n', reply=reply)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')

    def test_not_found_allows_manual_entry(self):
        result = self.select(reply='192.0.2.10\n', status=1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '192.0.2.10\n')

    def test_not_found_without_input_cancels(self):
        result = self.select(status=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')

    def test_discovery_error_offers_manual_entry(self):
        result = self.select(reply='printer.example\n', status=2)
        self.assertEqual(result.stdout, 'printer.example\n')
        self.assertIn('could not complete', result.stderr)

    def test_invalid_and_loopback_advertisements_are_ignored(self):
        result = self.select('bad host\n$(touch nope)\nlocalhost\n127.0.0.1\n-good.local\ndell-good.local\n')
        self.assertEqual(result.stdout, 'dell-good.local\n')

    def test_explicit_address_skips_discovery(self):
        result = self.select(host='192.0.2.10')
        self.assertEqual(result.stdout, '192.0.2.10\n')
        self.assertFalse((self.folder / 'call').exists())

    def test_invalid_explicit_address_rejected(self):
        for host in ['bad address', '-option', 'printer;command']:
            with self.subTest(host=host):
                result = self.select(host=host)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
