"""Turn `flutter test --file-reporter json:...` output into GitHub annotations.

Phase 6.7: job logs need a token, but check-run annotations are public, so a
failing test used to be visible only as "373 tests passed, 1 failed." This
prints one `::error` per failed test — its name, file and line, and the start
of its error — so the failure can be read from the check-run's annotations.
Runs only when the Test step failed.
"""
import json
import sys
from urllib.parse import urlparse


def escape_data(value: str) -> str:
    return value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')


def escape_property(value: str) -> str:
    return escape_data(value).replace(':', '%3A').replace(',', '%2C')


def main(path: str) -> None:
    tests = {}
    errors = {}
    failed = []
    with open(path, encoding='utf-8') as events:
        for line in events:
            line = line.strip()
            if not line.startswith('{'):
                continue
            event = json.loads(line)
            kind = event.get('type')
            if kind == 'testStart':
                test = event['test']
                tests[test['id']] = test
            elif kind == 'error':
                errors.setdefault(event['testID'], []).append(event.get('error', ''))
            elif kind == 'testDone' and event.get('result') != 'success' and not event.get('hidden'):
                failed.append(event['testID'])
    for test_id in failed:
        test = tests.get(test_id, {})
        url = test.get('root_url') or test.get('url') or ''
        file = urlparse(url).path if url.startswith('file:') else url
        marker = '/apps/mobile/'
        if marker in file:
            file = 'apps/mobile/' + file.split(marker, 1)[1]
        line = test.get('root_line') or test.get('line') or 1
        message = ' | '.join(errors.get(test_id, ['(no error text)']))[:900]
        print(
            f"::error file={escape_property(file)},line={line},"
            f"title={escape_property(test.get('name', 'unknown test')[:240])}::{escape_data(message)}"
        )
    print(f'{len(failed)} failed test(s) annotated')


if __name__ == '__main__':
    main(sys.argv[1])
