"""App-bound pending/final check lifecycle, synthetic GitHub only."""
import copy
import os
import unittest
from unittest.mock import patch

import runtime
import trust
from review_contract import InvalidReview


class MergeCheckTests(unittest.TestCase):
    def setUp(self):
        self.binding = dict(repository='example/repository',
                            publication_merge_gate=copy.deepcopy(trust.MERGE_GATE))
        self.head = 'a' * 40
        self.url = 'https://github.com/example/repository/actions/runs/14'
        self.prior = dict(id=123, name='Preloop merge gate', head_sha=self.head,
            status='in_progress', conclusion=None, external_id='briar-preloop-merge:10',
            details_url='https://github.com/example/repository/actions/runs/10',
            app={'id': 15368, 'slug': 'github-actions'})
        self.writes = []
        self.mutate = lambda value: value
        env = patch.dict(os.environ, GITHUB_RUN_ID='14')
        env.start()
        self.addCleanup(env.stop)

    def github(self, path, method='GET', body=None):
        if method in ['POST', 'PATCH']:
            self.writes.append((path, method, body))
            self.observed = dict(self.prior, **body)
            return {'id': 123}
        return self.mutate(copy.deepcopy(self.observed))

    def finish(self, rows=None):
        with patch.object(runtime, 'github_pages', return_value=[self.prior] if rows is None else rows):
            return runtime.merge_check(self.github, self.binding, self.head, self.url, trigger_run_id='10')

    def test_pending_created_then_exact_trigger_check_completed(self):
        runtime.merge_check(self.github, self.binding, self.head, self.url)
        self.assertEqual(self.writes[0][1], 'POST')
        self.assertEqual(self.writes[0][2]['status'], 'in_progress')
        self.assertNotIn('conclusion', self.writes[0][2])
        self.assertEqual(self.writes[0][2]['external_id'], 'briar-preloop-merge:14')
        self.finish()
        self.assertEqual(self.writes[-1][0], '/repos/example/repository/check-runs/123')
        self.assertEqual(self.writes[-1][1], 'PATCH')
        self.assertEqual(self.writes[-1][2]['conclusion'], 'success')
        self.assertEqual(self.writes[-1][2]['external_id'], 'briar-preloop-merge:10')

    def test_forged_stale_completed_or_wrong_trigger_check_cannot_be_completed(self):
        for key, value in [('head_sha', 'b' * 40), ('app', {'id': 99}),
                           ('external_id', 'briar-preloop-merge:99'),
                           ('status', 'completed'), ('conclusion', 'success'),
                           ('details_url', self.url)]:
            prior = copy.deepcopy(self.prior)
            self.prior[key] = value
            with self.subTest(key=key), self.assertRaises(InvalidReview):
                self.finish()
            self.assertEqual(self.writes, [])
            self.prior = prior
        for rows in [[], [self.prior, self.prior]]:
            with self.assertRaises(InvalidReview):
                self.finish(rows)

    def test_wrong_app_commit_conclusion_or_id_in_readback_fails(self):
        for key, value in [('head_sha', 'b' * 40), ('app', {'id': 99}),
                           ('conclusion', 'failure'), ('id', 124), ('id', True),
                           ('external_id', 'briar-preloop-merge:99')]:
            self.mutate = lambda row, key=key, value=value: dict(row, **{key: value})
            with self.subTest(key=key, value=value), self.assertRaises(InvalidReview):
                self.finish()

    def test_merge_context_never_uses_spoofable_status_even_with_signed_admission(self):
        with self.assertRaises(InvalidReview):
            runtime.commit_status(self.github, self.binding, self.head, 'success', self.url,
                                  'not admitted', context_name='Preloop merge gate')
        self.assertEqual(self.writes, [])


if __name__ == '__main__':
    unittest.main()
