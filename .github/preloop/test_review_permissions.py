"""Permission contract for the completed-publication API families."""
from pathlib import Path
import unittest


class ReviewPermissionTests(unittest.TestCase):
    def permissions(self, workflow):
        lines = (Path(__file__).resolve().parents[1] / 'workflows' / workflow).read_text().splitlines()
        start = lines.index('    permissions:') + 1
        permissions = {}
        for line in lines[start:]:
            if not line.startswith('      '):
                break
            scope, level = line.strip().split(': ', 1)
            permissions[scope] = level
        return permissions

    def test_completed_publication_api_families(self):
        # current_pr and completed_publication read pulls, reviews, check runs,
        # actions runs and source. Finalization additionally writes the check;
        # acceptance writes only its app-bound check. Never broaden to PR writes.
        for workflow, checks in [('preloop-review-finalize.yml', 'write'),
                                 ('preloop-review-merge.yml', 'write')]:
            with self.subTest(workflow=workflow):
                expected = {
                    'actions': 'read', 'contents': 'read', 'pull-requests': 'read',
                    'checks': checks, 'id-token': 'write'}
                if workflow == 'preloop-review-finalize.yml':
                    expected['statuses'] = 'write'
                self.assertEqual(self.permissions(workflow), expected)


if __name__ == '__main__':
    unittest.main()
