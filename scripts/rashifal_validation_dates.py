#!/usr/bin/env python3
"""Builds the Rashifal validation date list used by the daily workflow.

The workflow used to build this list with shell ``cat``/``echo``. When the
recovery file had no trailing newline, the last recovery date and the target
date were joined into one bogus date. Python's ``splitlines()`` keeps the two
sources separate and makes the behaviour straightforward to test.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_rashifal as g


def build_validation_dates(recovery_text: str, target_date: str) -> list[str]:
    """Return recovery dates plus the target date, unique and in first-seen order."""
    dates: list[str] = []
    errors: list[str] = []

    for line_number, raw_line in enumerate(recovery_text.splitlines(), start=1):
        value = raw_line.strip()
        if not value:
            continue
        if not g.is_valid_date_key(value):
            errors.append(f"recovery file line {line_number}: invalid date {value!r}")
            continue
        if value not in dates:
            dates.append(value)

    if not g.is_valid_date_key(target_date):
        errors.append(f"invalid target date {target_date!r}")

    if errors:
        raise ValueError("; ".join(errors))

    if target_date not in dates:
        dates.append(target_date)

    return dates


def write_validation_dates(
    recovery_file: Path, target_date: str, output_file: Path
) -> list[str]:
    """Read recovery dates, build the list, and write one date per line."""
    recovery_text = (
        recovery_file.read_text(encoding="utf-8-sig") if recovery_file.exists() else ""
    )
    dates = build_validation_dates(recovery_text, target_date)
    output_file.write_text("".join(f"{date}\n" for date in dates), encoding="utf-8")
    return dates


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--recovery-file", type=Path, default=Path(".recovery_dates"))
    parser.add_argument("--target-date", required=True)
    parser.add_argument("--output", type=Path, default=Path(".validation_dates"))
    args = parser.parse_args(argv)

    try:
        dates = write_validation_dates(args.recovery_file, args.target_date, args.output)
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"validation dates: {', '.join(dates)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
