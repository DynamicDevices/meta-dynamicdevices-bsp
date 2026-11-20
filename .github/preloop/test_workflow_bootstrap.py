"""No checkout executable may precede the workflow's immutable loader pin."""
import hashlib
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


def scripts(text):
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if not line.startswith('        run: '):
            continue
        value = line.removeprefix('        run: ')
        if value == '|':
            block = []
            for following in lines[index + 1:]:
                if following and not following.startswith('          '):
                    break
                block.append(following[10:])
            value = '\n'.join(block)
        yield value


def validate(text, digest):
    verified = False
    for script in scripts(text):
        if script.startswith("printf '%s\\n' "):
            pin = ("printf '%s\\n' '" + digest +
                   "  .github/preloop/bootstrap.py' | sha256sum --check --strict")
            if script.splitlines()[0] != pin or 'install_policy.py' in script:
                raise ValueError('Invalid bootstrap pin')
            if "python3 -I -B - <<'PY'" not in script:
                raise ValueError('Policy must use isolated inline code')
            verified = True
        elif not (verified and re.fullmatch(
                r'python3 -I -B \.github/preloop/bootstrap\.py (?:publisher (?:authenticate|publish|late-failure)|'
                r'trigger (?:prepare|start|startup)|finalize (?:prepare|release|accept)|event)', script)):
            raise ValueError('Checkout code before verified bootstrap')


class WorkflowBootstrapTests(unittest.TestCase):
    def setUp(self):
        self.raw = (ROOT / '.github/preloop/bootstrap.py').read_bytes()
        self.digest = hashlib.sha256(self.raw).hexdigest()

    def test_each_privileged_job_pins_loader_before_checkout_code(self):
        for name in ['trigger', 'publish', 'finalize', 'merge']:
            text = (ROOT / ('.github/workflows/preloop-review-' + name + '.yml')).read_text()
            # Each job is checked separately: a pin in authenticate cannot
            # accidentally satisfy the separate publish job.
            jobs = text.split('\njobs:\n', 1)[1]
            for job in re.split(r'^  [a-z_]+:\s*$', jobs, flags=re.M)[1:]:
                with self.subTest(workflow=name, job=job[:80]):
                    self.assertTrue(list(scripts(job)))
                    validate(job, self.digest)

    def test_unverified_checkout_script_and_wrong_pin_are_rejected(self):
        for text in [
            '        run: python3 -I -B .github/preloop/install_policy.py',
            '        run: python3 -I -B .github/preloop/bootstrap.py event',
            "        run: |\n          printf '%s\\n' 'wrong  .github/preloop/bootstrap.py' | sha256sum --check --strict",
        ]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                validate(text, self.digest)

    def test_mutated_bootstrap_fails_real_shell_pin_before_execution(self):
        text = (ROOT / '.github/workflows/preloop-review-merge.yml').read_text()
        command = next(scripts(text)).splitlines()[0]
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / '.github/preloop/bootstrap.py'
            target.parent.mkdir(parents=True)
            target.write_bytes(self.raw + b'\n# unapproved mutation\n')
            result = subprocess.run(['bash', '-e', '-c', command + '\nexit 99'],
                                    cwd=folder, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotEqual(result.returncode, 99)

    def test_inline_install_preserves_exact_environment_bytes(self):
        text = (ROOT / '.github/workflows/preloop-review-merge.yml').read_text()
        command = next(scripts(text))
        values = {'PRELOOP_PUBLICATION_AUTHORITY': 'synthetic policy é\n\n',
                  'PRELOOP_PUBLICATION_SIGNATURE': 'synthetic signature\n'}
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / '.github/preloop/bootstrap.py'
            target.parent.mkdir(parents=True)
            target.write_bytes(self.raw)
            result = subprocess.run(['bash', '-e', '-c', command],
                                    cwd=folder, env=values, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            for variable, name in [
                ('PRELOOP_PUBLICATION_AUTHORITY', 'preloop-publication-authority.json'),
                ('PRELOOP_PUBLICATION_SIGNATURE', 'preloop-publication-authority.json.sig'),
            ]:
                self.assertEqual((Path(folder) / '.github' / name).read_bytes(),
                                 values[variable].encode('utf-8'))


if __name__ == '__main__':
    unittest.main()
