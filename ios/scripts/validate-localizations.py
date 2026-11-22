#!/usr/bin/env python3
"""Validate shipped locales, interpolation arguments and optional compiler-extracted coverage."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys

LOCALES = set('en-US ar bn ca zh-Hans zh-Hant hr cs da nl en-AU en-CA en-GB fi fr fr-CA de el gu he hi hu id it ja kn ko ms ml mr nb or pl pt-BR pt-PT pa ro ru sk sl es-MX es-ES sv ta te th tr uk ur vi'.split())
APP = Path(__file__).resolve().parents[1] / 'CollageMagik' / 'CollageMagik'
FORMAT = re.compile(r'%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?(ll|l|hh|h|z|t|j)?([@diuoxXfFeEgGcs])|%%')


def arguments(value):
    result = []
    implicit = 0
    for match in FORMAT.finditer(value):
        if match.group() == '%%':
            continue
        implicit += 1
        position = int(match[1]) if match[1] else implicit
        result.append((position, (match[2] or '') + match[3]))
    return Counter(result)


def units(localization):
    if 'stringUnit' in localization:
        yield localization['stringUnit']
    for variants in localization.get('variations', {}).values():
        for variant in variants.values():
            yield from units(variant)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--extracted-dir', type=Path, help='Objects-normal/arm64 directory from a fresh Xcode build')
    args = parser.parse_args()
    errors = []
    reviewed = Counter()
    catalogs = {}
    for filename in ['Localizable.xcstrings', 'InfoPlist.xcstrings']:
        path = APP / filename
        catalog = json.loads(path.read_text())
        catalogs[filename] = catalog
        if catalog['sourceLanguage'] != 'en-US':
            errors.append(f'{filename}: source language must be en-US')
        for key, entry in catalog['strings'].items():
            if entry.get('shouldTranslate') is False:
                continue
            localizations = entry.get('localizations', {})
            if set(localizations) != LOCALES:
                errors.append(f'{filename} / {key}: locale mismatch: missing {sorted(LOCALES - set(localizations))}, extra {sorted(set(localizations) - LOCALES)}')
            source = localizations.get('en-US', {}).get('stringUnit', {}).get('value', key)
            expected = arguments(source)
            for locale, localization in localizations.items():
                strings = list(units(localization))
                if not strings:
                    errors.append(f'{filename} / {locale} / {key}: no string values')
                for unit in strings:
                    value = unit.get('value', '')
                    if not value.strip() or re.search(r'[\[【]\s*\d{4}\s*[\]】]|\{(?:BR|\d+)\}', value):
                        errors.append(f'{filename} / {locale} / {key}: empty value or leaked translation token')
                    if arguments(value) != expected:
                        errors.append(f'{filename} / {locale} / {key}: format arguments changed: {value!r}')
                    if unit.get('state') == 'needs_review':
                        reviewed[locale] += 1
        print(f'{filename}: {len(catalog["strings"])} keys')
    if args.extracted_dir:
        extracted = set()
        files = list(args.extracted_dir.glob('*.stringsdata'))
        if not files:
            errors.append('No compiler .stringsdata files found in --extracted-dir')
        for path in files:
            data = json.loads(path.read_text())
            extracted.update(entry['key'] for entry in data.get('tables', {}).get('Localizable', []))
        for key in sorted(extracted - catalogs['Localizable.xcstrings']['strings'].keys()):
            errors.append(f'Compiler-extracted string is missing from Localizable.xcstrings: {key}')
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f'FAILED: {len(errors)} localization errors.', file=sys.stderr)
        return 1
    print(f'PASS: {len(LOCALES)} locales, source coverage and format arguments valid.')
    print(f'Translation drafts awaiting review: {sum(reviewed.values())} string values across {len(reviewed)} locales.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
