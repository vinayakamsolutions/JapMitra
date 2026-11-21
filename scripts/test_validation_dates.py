#!/usr/bin/env python3
"""Regression tests for the Rashifal workflow recovery and notification fixes."""

from __future__ import annotations

import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from rashifal_validation_dates import build_validation_dates, write_validation_dates


class ValidationDatesTest(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.recovery = self.tmp / ".recovery_dates"
        self.output = self.tmp / ".validation_dates"

    def write_recovery(self, text: str) -> None:
        self.recovery.write_text(text, encoding="utf-8")

    def run_helper(self, target: str) -> list[str]:
        dates = write_validation_dates(self.recovery, target, self.output)
        self.assertEqual(
            self.output.read_text(encoding="utf-8"),
            "".join(f"{date}\n" for date in dates),
        )
        return dates

    def test_recovery_file_without_trailing_newline(self) -> None:
        self.write_recovery("2026-11-18\n2026-11-19")
        self.assertEqual(
            self.run_helper("2026-11-21"),
            ["2026-11-18", "2026-11-19", "2026-11-21"],
        )
        self.assertEqual(
            self.output.read_text(encoding="utf-8"),
            "2026-11-18\n2026-11-19\n2026-11-21\n",
        )

    def test_multiple_recovery_dates(self) -> None:
        self.write_recovery("2026-11-18\n2026-11-19\n2026-11-20\n")
        self.assertEqual(
            self.run_helper("2026-11-21"),
            ["2026-11-18", "2026-11-19", "2026-11-20", "2026-11-21"],
        )

    def test_empty_recovery_file(self) -> None:
        self.write_recovery("")
        self.assertEqual(self.run_helper("2026-11-21"), ["2026-11-21"])
        self.write_recovery("  \n\t\n")
        self.assertEqual(self.run_helper("2026-11-21"), ["2026-11-21"])
        self.assertEqual(self.output.read_text(encoding="utf-8"), "2026-11-21\n")

    def test_recovery_file_with_trailing_newline(self) -> None:
        self.write_recovery("  2026-11-18  \n")
        self.assertEqual(self.run_helper("2026-11-21"), ["2026-11-18", "2026-11-21"])

    def test_duplicate_dates_preserve_order(self) -> None:
        self.write_recovery("2026-11-20\n2026-11-18\n2026-11-20")
        self.assertEqual(
            self.run_helper("2026-11-21"),
            ["2026-11-20", "2026-11-18", "2026-11-21"],
        )
        self.write_recovery("2026-11-21\n2026-11-20")
        self.assertEqual(self.run_helper("2026-11-21"), ["2026-11-21", "2026-11-20"])

    def test_invalid_date_format_reports_line_numbers(self) -> None:
        self.write_recovery("2026-11-18\nnot-a-date\n2026/11/20")
        with self.assertRaises(ValueError) as raised:
            self.run_helper("2026-11-21")
        self.assertIn("line 2", str(raised.exception))
        self.assertIn("line 3", str(raised.exception))
        self.assertFalse(self.output.exists())

    def test_invalid_calendar_date_reports_line_numbers(self) -> None:
        for bad_date in ("2026-02-30", "2026-11-31", "2026-13-01"):
            with self.subTest(bad_date=bad_date):
                self.write_recovery(f"2026-11-18\n{bad_date}")
                with self.assertRaisesRegex(ValueError, "line 2"):
                    self.run_helper("2026-11-21")

    def test_target_date_appended_separately(self) -> None:
        self.write_recovery("2026-11-20")
        self.assertEqual(self.run_helper("2026-11-21"), ["2026-11-20", "2026-11-21"])
        self.assertEqual(
            self.output.read_text(encoding="utf-8"), "2026-11-20\n2026-11-21\n"
        )
        with self.assertRaisesRegex(ValueError, "invalid target date"):
            build_validation_dates("", "2026-11-21x")


class WorkflowConfigTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = (ROOT / ".github/workflows/generate-rashifal.yml").read_text(
            encoding="utf-8"
        )

    def notify_step(self) -> str:
        lines = self.workflow.splitlines()
        start = next(
            i for i, line in enumerate(lines) if "- name: Notify on failure" in line
        )
        block = [lines[start]]
        for line in lines[start + 1 :]:
            if re.match(r"^\s*- name:", line) or re.match(r"^\S", line):
                break
            block.append(line)
        return "\n".join(block)

    def test_missing_github_issue_labels_do_not_break_notification(self) -> None:
        step = self.notify_step()
        self.assertIn("gh issue create", step)
        self.assertNotIn("--label", step)
        self.assertIn("continue-on-error: true", step)
        self.assertIn("if: failure()", step)
        self.assertIn("GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}", step)

    def test_validation_step_uses_helper_and_keeps_json_validation(self) -> None:
        self.assertIn("python scripts/rashifal_validation_dates.py", self.workflow)
        self.assertNotIn('cat .recovery_dates >> "$DATES_FILE"', self.workflow)
        self.assertNotIn('echo "$TARGET_DATE" >> "$DATES_FILE"', self.workflow)
        self.assertIn("g.validate(day)", self.workflow)
        self.assertIn('day.get("date") != date_str', self.workflow)
        self.assertIn('"".join(f"{d}\\n" for d in missing)', self.workflow)

    def test_permissions_unchanged(self) -> None:
        self.assertIn("contents: write", self.workflow)
        self.assertIn("issues: write", self.workflow)


if __name__ == "__main__":
    unittest.main()
