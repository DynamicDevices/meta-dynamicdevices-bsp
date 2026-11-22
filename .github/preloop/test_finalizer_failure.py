"""Failure-only finalizer recovery and non-mutating terminal replay."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import finalize
import runtime
import trust


class FinalizerFailureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        event = Path(self.temp.name) / 'event.json'
        event.write_text(json.dumps(dict(action='completed', repository={'id': 42},
            workflow_run={'id': 12, 'path': '.github/workflows/preloop-review-publish.yml'})))
        env = patch.dict(os.environ, GITHUB_EVENT_NAME='workflow_run',
            GITHUB_EVENT_PATH=str(event), GITHUB_RUN_ID='14', GITHUB_RUN_ATTEMPT='1',
            RUNNER_TEMP=self.temp.name, PRELOOP_CI_TOKEN='synthetic')
        env.start()
        self.addCleanup(env.stop)
        self.binding = dict(repository='example/repository', repository_id=42,
                            publication_merge_gate=trust.MERGE_GATE)
        self.completion = dict(execution_id='487d988a-53ad-4f5d-8b84-d77bb733676f',
                               pr_number=7, head_sha='a' * 40, base_sha='b' * 40)
        self.eid = self.completion['execution_id']
        self.trigger = dict(self.completion, trigger_run_id='10')

    def failed_producer(self):
        rows = [dict(name='preloop-wake-' + self.eid, expired=False)]
        with patch.object(finalize, 'producer', side_effect=OSError('Original producer failed')), \
             patch.object(runtime, 'github_pages', return_value=rows), \
             patch.object(runtime, 'artifact', side_effect=[dict(completion=self.completion), self.trigger]), \
             patch.object(runtime, 'current_pr'), patch.object(finalize.publisher, 'no_supersession'), \
             patch.object(runtime, 'fail_merge_check') as cleanup:
            with self.assertRaisesRegex(OSError, 'Original producer failed'):
                finalize.producer_or_fail(lambda *args: self.fail('Unexpected API'), self.binding)
            return cleanup

    def test_failed_prepare_or_publisher_uses_authenticated_trigger_failure_target(self):
        cleanup = self.failed_producer()
        cleanup.assert_called_once()
        self.assertEqual(cleanup.call_args.args[2:], ('a' * 40, '10'))
        report = json.loads((Path(self.temp.name) /
            'preloop-finalize-preparation-failure/receipt.json').read_text())
        self.assertTrue(report['failure_correction_confirmed'])

    def test_mismatched_failure_target_never_writes_and_preserves_original_error(self):
        self.trigger['head_sha'] = 'c' * 40
        self.failed_producer().assert_not_called()

    def test_verified_duplicate_finalization_skips_without_reset_or_new_intent(self):
        replay = dict(self.completion, original_publisher_run_id='11')
        rows = [dict(name='preloop-terminal-replay-' + self.eid, expired=False)]
        accepted = dict(delivery_verified=True, actions_run_verified=True,
                        actions_check_verified=True, review_approved=True)
        with patch.object(runtime, 'context', return_value=(self.binding, {}, lambda *a: None)), \
             patch.object(runtime, 'github_pages', return_value=rows), \
             patch.object(runtime, 'artifact', return_value=replay), \
             patch.object(runtime, 'completed_publication', return_value=accepted), \
             patch.object(runtime, 'fail_merge_check') as cleanup, \
             patch.object(runtime, 'write_receipt') as receipt, \
             patch.object(runtime, 'output') as output:
            finalize.prepare()
            output.assert_called_once_with(terminal_replay='true')
            receipt.assert_not_called()
            cleanup.assert_not_called()


if __name__ == '__main__':
    unittest.main()
