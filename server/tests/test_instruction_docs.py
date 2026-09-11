"""Project document boundary tests; never import the running server."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import types
import unittest
from unittest.mock import patch

from fastapi import HTTPException
from test_review_regressions import ROOT, extract


class InstructionDocs(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.project = types.SimpleNamespace(project_path=str(self.path))
        self.workers = []

        class CapturedThread:
            def __init__(inner, target, **kw):
                inner.target = target

            def start(inner):
                self.workers.append(inner.target)

        self.env = {
            'os': os, 'json': json, 'subprocess': subprocess,
            'HTTPException': HTTPException,
            'db': lambda: types.SimpleNamespace(get_app=lambda app_id: self.project if app_id == 7 else None),
            '_enhance_status': {}, '_enhance_lock': threading.Lock(),
            'threading': types.SimpleNamespace(Thread=CapturedThread),
            '_get_tool_paths': lambda: {'claude_bin': 'fixture-cli', 'bash_exe': 'fixture-shell'},
        }
        extract(ROOT / 'api/server.py', {'get_agents_md', 'update_agents_md', '_write_instruction_doc', 'enhance_doc'}, self.env)
        (self.path / 'CLAUDE.md').write_text('Original Claude instructions', encoding='utf-8')

    def test_missing_read_and_utf8_save_leave_claude_unchanged(self):
        self.assertEqual(self.env['get_agents_md'](7), {'content': '', 'exists': False})
        self.assertFalse((self.path / 'AGENTS.md').exists())
        content = '# Türkçe instructions\nÇağatay — 日本語\n\n'
        self.env['update_agents_md'](7, types.SimpleNamespace(content=content))
        self.assertEqual(self.env['get_agents_md'](7), {'content': content, 'exists': True})
        self.assertEqual((self.path / 'CLAUDE.md').read_text(encoding='utf-8'), 'Original Claude instructions')
        self.assertEqual(list(self.path.glob('*.tmp')), [])

    def test_unknown_app_and_missing_directory_return_404(self):
        for name, args in [('get_agents_md', (8,)), ('update_agents_md', (8, types.SimpleNamespace(content='x')))]:
            with self.assertRaises(HTTPException) as error:
                self.env[name](*args)
            self.assertEqual(error.exception.status_code, 404)
        self.project.project_path = str(self.path / 'missing')
        with self.assertRaises(HTTPException) as error:
            self.env['update_agents_md'](7, types.SimpleNamespace(content='x'))
        self.assertEqual(error.exception.status_code, 404)

    def test_failed_replace_keeps_previous_document_and_cleans_temp(self):
        target = self.path / 'AGENTS.md'
        target.write_text('Previous content', encoding='utf-8')
        with patch.object(os, 'replace', side_effect=PermissionError('fixture locked file')):
            with self.assertRaises(PermissionError):
                self.env['update_agents_md'](7, types.SimpleNamespace(content='New content'))
        self.assertEqual(target.read_text(encoding='utf-8'), 'Previous content')
        self.assertEqual(list(self.path.glob('*.tmp')), [])

    def test_enhancement_targets_agents_file_and_rejects_other_document(self):
        self.env['update_agents_md'](7, types.SimpleNamespace(content='Original agent instructions'))
        self.env['enhance_doc'](7, types.SimpleNamespace(type='agents-md'))
        self.assertEqual(len(self.workers), 1)
        with self.assertRaises(HTTPException) as error:
            self.env['enhance_doc'](7, types.SimpleNamespace(type='claude-md'))
        self.assertEqual(error.exception.status_code, 409)
        enhanced = '# Enhanced AGENTS.md\n' + 'Keep all existing project rules. ' * 3
        prompts = []
        def communicate(input, **kw):
            prompts.append(input.decode('utf-8'))
            return json.dumps({'result': enhanced}).encode('utf-8'), None
        with patch.object(subprocess, 'Popen', return_value=types.SimpleNamespace(communicate=communicate)):
            self.workers[0]()
        self.assertIn('Current AGENTS.md:', prompts[0])
        self.assertNotIn('Current CLAUDE.md:', prompts[0])
        self.assertEqual((self.path / 'AGENTS.md').read_text(encoding='utf-8'), enhanced.strip())
        self.assertEqual((self.path / 'CLAUDE.md').read_text(encoding='utf-8'), 'Original Claude instructions')
        self.assertEqual(self.env['_enhance_status'][7]['status'], 'done')
