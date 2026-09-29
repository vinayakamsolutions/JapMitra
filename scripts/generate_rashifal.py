#!/usr/bin/env python3
"""Generates one day of original Rashifal content for all twelve signs.

This is the zero-cost half of the daily Rashifal system. It runs on a schedule
(see .github/workflows/generate-rashifal.yml) and writes a single JSON file per
calendar day, which the app then reads over the network.

Design notes:

* No paid AI, no API keys, no network calls. Every line is picked from a fixed
  set of original templates, so the whole thing costs nothing to run and can be
  re-run any number of times.
* Deterministic. The choice of template for a given sign on a given day comes
  from a hash of the date and the sign key, so re-running a day reproduces it
  exactly. A failed workflow can simply be re-run.
* Original text. Nothing is copied from a horoscope site, and nothing promises a
  specific outcome. The app pairs this content with a disclaimer saying it is
  traditional guidance, not a prediction.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# India Standard Time. The schedule is expressed in UTC on GitHub, so the date
# has to be resolved here rather than on the runner.
IST = timezone(timedelta(hours=5, minutes=30))

# The twelve signs, in the traditional order. These keys are shared with the app
# (lib/features/rashifal/models/daily_rashifal.dart) and with storage, so they are
# the contract between this script and the UI.
SIGNS = [
    "mesha",
    "vrishabha",
    "mithun",
    "karka",
    "simha",
    "kanya",
    "tula",
    "vrishchik",
    "dhanu",
    "makar",
    "kumbh",
    "meen",
]

# Every category a day must carry. The app renders all of them, so a day missing
# one is not a usable day.
CATEGORIES = ["general", "career", "finance", "love", "health", "guidance"]

# Traditional lucky colours, offered in both languages.
COLOURS = {
    "hi": [
        "सुनहरा",
        "केसरिया",
        "गहरा लाल",
        "हल्का हरा",
        "सफ़ेद",
        "नीला",
        "बैंगनी",
        "गुलाबी",
    ],
    "en": [
        "golden",
        "saffron",
        "deep red",
        "light green",
        "white",
        "blue",
        "violet",
        "pink",
    ],
}

# One quality per sign, used to give each sign's guidance its own flavour.
QUALITY = {
    "hi": {
        "mesha": "आत्मविश्वास",
        "vrishabha": "धैर्य",
        "mithun": "समझदारी",
        "karka": "संवेदनशीलता",
        "simha": "नेतृत्व",
        "kanya": "व्यवस्थितता",
        "tula": "संतुलन",
        "vrishchik": "एकाग्रता",
        "dhanu": "उत्साह",
        "makar": "अनुशासन",
        "kumbh": "सेवा भाव",
        "meen": "कल्पना",
    },
    "en": {
        "mesha": "confidence",
        "vrishabha": "patience",
        "mithun": "thoughtfulness",
        "karka": "sensitivity",
        "simha": "leadership",
        "kanya": "orderliness",
        "tula": "balance",
        "vrishchik": "focus",
        "dhanu": "enthusiasm",
        "makar": "discipline",
        "kumbh": "a spirit of service",
        "meen": "imagination",
    },
}

# Original templates, per language and category.
#
# `{name}` is replaced with the sign's name in that language. The guidance
# templates also carry `{quality}`, the sign's ruling quality. Everything here
# is written for this project; none of it is lifted from another source.
TEMPLATES = {
    "hi": {
        "general": [
            "आपका दिन संतुलित रहने की संभावना है। धैर्य रखें और योजना के अनुसार आगे बढ़ें।",
            "{name} राशि के लिए आज नए विचारों को अपनाने का अवसर है।",
            "आज का दिन संतुलन बनाए रखने पर जोर देता है। जल्दबाज़ी से बचें।",
            "पहले से चल रहे कार्यों में आज प्रगति दिखाई दे सकती है।",
            "आज मन की शांति बनाए रखना मुख्य है; छोटी जीतें अपने आप मिलेंगी।",
        ],
        "career": [
            "कार्यस्थल पर आपकी मेहनत की सराहना हो सकती है।",
            "नई जिम्मेदारी स्वीकारने से पहले अपनी तैयारी अच्छी तरह जांचें।",
            "आज किसी अनुभवी व्यक्ति की सलाह लेना फायदेमंद रहेगा।",
            "लंबित कार्यों को प्राथमिकता दें और एक-एक करके पूरा करें।",
            "धैर्य से किया गया काम आज अच्छे परिणाम दे सकता है।",
        ],
        "finance": [
            "आय और व्यय का हिसाब रखना आज विशेष उपयोगी रहेगा।",
            "बिना आवश्यकता के खर्च से बचें और बचत पर ध्यान दें।",
            "पुराने वित्तीय निर्णयों की समीक्षा करने का अवसर है।",
            "आज बड़े वित्तीय सौदों से बचना बेहतर है।",
            "छोटी बचत भी आगे चलकर बड़ा योगदान दे सकती है।",
        ],
        "love": [
            "प्रियजनों के साथ संवाद में साफ़-साफ़ बात करें।",
            "आज किसी प्रियजन की भावनाओं को समझने का दिन है।",
            "परिवार के साथ समय बिताने से संबंध मज़बूत होंगे।",
            "छोटी सी नेक इच्छा भी बड़ा फर्क डाल सकती है।",
            "धैर्य और समझ से विवाद सुलझाने में आसानी होगी।",
        ],
        "health": [
            "नियमित भोजन और पर्याप्त नींद आज विशेष मायने रखते हैं।",
            "हल्की व्यायाम या सैर से ऊर्जा बनाए रहेगी।",
            "आज अतिरिक्त तनाव से बचें और विश्राम को प्राथमिकता दें।",
            "पर्याप्त पानी पिएं और संतुलित आहार का ध्यान रखें।",
            "सुबह की सैर मन और शरीर दोनों को तरोताज़ा करेगी।",
        ],
        "guidance": [
            "आज धैर्य और निरंतरता आपके सबसे बड़े साथी रहेंगे। {quality} को अपनाएं।",
            "पहले उस काम पर ध्यान दें जो सबसे ज़्यादा बाकी है। {quality} यहाँ काम आएगा।",
            "काम और विश्राम का संतुलन बनाए रखें। {quality} आपको सही राह दिखाएगा।",
            "छोटे लक्ष्य तय करें और उन्हें पूरा करते रहें। {quality} से काम आसान होगा।",
            "आज अपने भीतर की शांति पर ज़ोर दें। {quality} आपको संतुलन देगा।",
        ],
    },
    "en": {
        "general": [
            "Your day is likely to stay balanced. Be patient and follow your plan.",
            "For {name} signs, today favours adopting a fresh approach.",
            "The day stresses balance; avoid rushing into decisions.",
            "Progress on ongoing work may become visible today.",
            "Keeping a calm mind is the main theme; small wins will come on their own.",
        ],
        "career": [
            "Your hard work is likely to be noticed at work.",
            "Before taking on a new responsibility, check your preparation.",
            "Advice from an experienced person will prove useful today.",
            "Prioritise pending tasks and finish them one at a time.",
            "Patient effort is likely to bring good results today.",
        ],
        "finance": [
            "Tracking income and expenses is especially useful today.",
            "Avoid spending without need; focus on saving.",
            "It is a good day to review past financial decisions.",
            "It is better to avoid major financial commitments today.",
            "Small savings can make a big difference over time.",
        ],
        "love": [
            "Speak clearly and openly with loved ones.",
            "Today is a day for understanding a loved one's feelings.",
            "Spending time with family will strengthen bonds.",
            "A small kind gesture can make a big difference.",
            "Patience and understanding will ease disagreements.",
        ],
        "health": [
            "Regular meals and enough sleep matter especially today.",
            "Light exercise or a walk will keep your energy up.",
            "Avoid extra strain today; prioritise rest.",
            "Drink enough water and keep your diet balanced.",
            "A morning walk will refresh both mind and body.",
        ],
        "guidance": [
            "Patience and consistency will be your greatest allies today. Embrace {quality}.",
            "Focus first on the task that is most overdue. {quality} will help here.",
            "Keep a balance between work and rest. {quality} will show you the way.",
            "Set small goals and keep completing them. {quality} makes the work easier.",
            "Today, emphasise inner calm. {quality} will keep you steady.",
        ],
    },
}

# Sign names, in both scripts, for the {name} placeholder.
SIGN_NAMES = {
    "hi": {
        "mesha": "मेष",
        "vrishabha": "वृषभ",
        "mithun": "मिथुन",
        "karka": "कर्क",
        "simha": "सिंह",
        "kanya": "कन्या",
        "tula": "तुला",
        "vrishchik": "वृश्चिक",
        "dhanu": "धनु",
        "makar": "मकर",
        "kumbh": "कुंभ",
        "meen": "मीन",
    },
    "en": {
        "mesha": "Mesha",
        "vrishabha": "Vrishabha",
        "mithun": "Mithun",
        "karka": "Karka",
        "simha": "Simha",
        "kanya": "Kanya",
        "tula": "Tula",
        "vrishchik": "Vrishchik",
        "dhanu": "Dhanu",
        "makar": "Makar",
        "kumbh": "Kumbh",
        "meen": "Meen",
    },
}


def is_valid_date_key(value: object) -> bool:
    """Returns whether value is an exact, real YYYY-MM-DD calendar date."""
    if not isinstance(value, str):
        return False
    try:
        parsed = datetime.strptime(value, "%Y-%m-%d")
    except ValueError:
        return False
    return parsed.date().isoformat() == value


def seed_for(date_str: str, sign: str) -> int:
    """A stable per-day, per-sign seed.

    Python's built-in hash() is randomised per process for strings, so it cannot
    be used here: a re-run would produce different content. A digest of the date
    and sign is stable across runs and machines, which is what makes a failed
    workflow safe to re-run.
    """
    digest = hashlib.sha256(f"{date_str}:{sign}".encode("utf-8")).hexdigest()
    return int(digest[:12], 16)


def pick(options: list, seed: int) -> str:
    return options[seed % len(options)]


def generate_day(date_str: str) -> dict:
    """Builds the full payload for one calendar day."""
    day = {
        "date": date_str,
        "generator": "scripts/generate_rashifal.py",
        "languages": {},
    }

    for language in ("hi", "en"):
        signs = {}
        for sign in SIGNS:
            seed = seed_for(date_str, sign)
            name = SIGN_NAMES[language][sign]
            quality = QUALITY[language][sign]

            def text(category: str) -> str:
                template = pick(TEMPLATES[language][category], seed)
                return template.format(name=name, quality=quality)

            signs[sign] = {
                "general": text("general"),
                "career": text("career"),
                "finance": text("finance"),
                "love": text("love"),
                "health": text("health"),
                "luckyNumber": (seed % 9) + 1,
                "luckyColour": pick(COLOURS[language], seed >> 8),
                "guidance": text("guidance"),
            }
        day["languages"][language] = signs

    return day


def validate(day: dict) -> list[str]:
    """Returns a list of problems; an empty list means the day is usable."""
    errors: list[str] = []

    date = day.get("date")
    if not is_valid_date_key(date):
        errors.append(f"date must be a valid YYYY-MM-DD calendar date, got {date!r}")

    languages = day.get("languages")
    if not isinstance(languages, dict):
        return errors + ["languages must be an object"]

    for language in ("hi", "en"):
        signs = languages.get(language)
        if not isinstance(signs, dict):
            errors.append(f"missing language block: {language}")
            continue
        for sign in SIGNS:
            entry = signs.get(sign)
            if not isinstance(entry, dict):
                errors.append(f"{language}/{sign}: missing")
                continue
            for category in CATEGORIES:
                value = entry.get(category)
                if not isinstance(value, str) or not value.strip():
                    errors.append(f"{language}/{sign}: {category} is empty")
            number = entry.get("luckyNumber")
            if not isinstance(number, int) or isinstance(number, bool) or not 1 <= number <= 9:
                errors.append(f"{language}/{sign}: luckyNumber must be 1-9")
            colour = entry.get("luckyColour")
            if not isinstance(colour, str) or not colour.strip():
                errors.append(f"{language}/{sign}: luckyColour is empty")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--date",
        help="YYYY-MM-DD to generate. Defaults to the current IST calendar date.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("data/rashifal"),
        help="Directory to write the day file into.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite an existing day file even if it already validates.",
    )
    args = parser.parse_args()

    # The date is resolved in IST so the file always names the day the user in
    # India is actually waking up to, whatever timezone the runner is in.
    date_str = args.date or datetime.now(IST).strftime("%Y-%m-%d")

    if not is_valid_date_key(date_str):
        print(
            f"error: --date must be a valid YYYY-MM-DD calendar date, got {date_str!r}",
            file=sys.stderr,
        )
        return 2

    args.output_dir.mkdir(parents=True, exist_ok=True)
    target = args.output_dir / f"{date_str}.json"

    # Never clobber a good day. Re-running a schedule should be a no-op, and an
    # existing valid file is evidence the day was already published.
    if target.exists() and not args.force:
        try:
            # utf-8-sig tolerates a byte order mark, which some editors add and
            # which would otherwise make an otherwise readable file look broken.
            existing = json.loads(target.read_text(encoding="utf-8-sig"))
        except (OSError, ValueError) as exc:
            print(
                f"error: existing {target} is unreadable or not valid JSON: {exc}",
                file=sys.stderr,
            )
            return 1
        errors = validate(existing)
        if errors:
            print(
                f"error: existing {target} is invalid and would need --force to replace:",
                file=sys.stderr,
            )
            for error in errors:
                print(f"  - {error}", file=sys.stderr)
            return 1
        print(f"ok: {target} already exists and is valid; nothing to do")
        return 0

    day = generate_day(date_str)
    errors = validate(day)
    if errors:
        # Refuse to write a day the app could not render.
        print(f"error: generated day for {date_str} failed validation:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    # Written as UTF-8 with ensure_ascii=False so the Hindi text stays readable
    # in the repository rather than being escaped.
    target.write_text(
        json.dumps(day, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
