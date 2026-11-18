#!/usr/bin/env python3
"""Inventory Markdown commit ages without modifying the repository (stdlib only)."""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args])


def inventory(repo, paths, newest_commits):
    root = Path(git(repo, 'rev-parse', '--show-toplevel').decode().strip())
    head = git(root, 'rev-parse', 'HEAD').decode().strip()
    names = git(root, 'ls-files', '-z', '--cached', '--others', '--exclude-standard',
                '--', *paths).decode().split('\0')
    dirty = set(git(root, 'diff', '--name-only', '-z', head, '--').decode().split('\0'))
    rows = []
    for name in sorted(set(names)):
        if not name.lower().endswith('.md') or not (root / name).is_file():
            continue
        # --follow retains history for committed renames; use literal pathspecs.
        history = git(root, '--literal-pathspecs', 'log', '--follow', '-1',
                      '--format=%H%x00%ct%x00%cI', head, '--', name).decode().strip()
        if history:
            commit, timestamp, date = history.split('\0')
            row = dict(path=name, commit=commit, timestamp=int(timestamp), date=date,
                       state='modified' if name in dirty else 'clean')
        else:
            row = dict(path=name, commit=None, timestamp=None, date=None,
                       state='uncommitted')
        rows.append(row)
    rows.sort(key=lambda r: (r['timestamp'] is None, r['timestamp'] or 0, r['path']))
    committed = [r for r in rows if r['commit']]
    latest = sorted(committed, key=lambda r: (-r['timestamp'], r['commit'], r['path']))
    groups = list(dict.fromkeys(r['commit'] for r in latest))[:newest_commits]
    return dict(repository=str(root), head=head,
                shallow=git(root, 'rev-parse', '--is-shallow-repository').strip() == b'true',
                files=rows,
                oldest=[r['path'] for r in committed
                        if r['timestamp'] == committed[0]['timestamp']],
                reference_commits=groups,
                reference_paths=[r['path'] for r in latest if r['commit'] in groups])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', default='.', help='Repository location (default: cwd)')
    parser.add_argument('--paths', nargs='+', default=['docs', '.codex/skills'],
                        help='Repo-relative Git pathspecs; use --paths . for all repo Markdown')
    parser.add_argument('--newest-commits', type=int, default=3,
                        help='Number of distinct recent commits in the reference cohort')
    parser.add_argument('--format', choices=['tsv', 'json'], default='tsv')
    args = parser.parse_args()
    if args.newest_commits < 1:
        parser.error('--newest-commits must be positive')
    try:
        report = inventory(args.repo, args.paths, args.newest_commits)
    except (subprocess.CalledProcessError, OSError) as error:
        parser.exit(1, f'Cannot read Git inventory: {error}\n')
    if args.format == 'json':
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print('last_commit_date\tlast_commit_hash\tstate\tpath')
        for row in report['files']:
            # JSON quoting keeps unusual filenames on one TSV line.
            print('\t'.join([row['date'] or '-', row['commit'] or '-', row['state'],
                             json.dumps(row['path'], ensure_ascii=False)]))
        print('Oldest: ' + json.dumps(report['oldest'], ensure_ascii=False), file=sys.stderr)
    if report['shallow']:
        print('Warning: shallow history; ages may reflect the history boundary.', file=sys.stderr)


if __name__ == '__main__':
    main()
