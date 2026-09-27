"""Works out the next version from the commit messages since the last v* tag.

    feat: ...            -> minor bump   (1.2.3 -> 1.3.0)
    fix: ... / other     -> patch bump   (1.2.3 -> 1.2.4)
    feat!: ... or a "BREAKING CHANGE:" footer line -> major bump (1.2.3 -> 2.0.0)
    docs: / ci: / test: / chore: / style: only -> no release

Prints shell-style lines for GitHub Actions ($GITHUB_OUTPUT):
    version=1.3.0
    release=true
and writes release notes (grouped by kind) to the file given as argv[1].
Run locally to preview:  python3 tools/next_version.py /tmp/notes.md
"""
import re
import subprocess
import sys

QUIET = {"docs", "ci", "test", "tests", "chore", "style", "build"}
TITLES = [("feat", "New"), ("fix", "Fixes"), ("perf", "Faster"), ("other", "Other changes")]


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=False).stdout.strip()


def main():
    last = git("describe", "--tags", "--abbrev=0", "--match", "v[0-9]*")
    base = last.lstrip("v") if last else "0.0.0"
    major, minor, patch = (int(x) for x in (base.split(".") + ["0", "0"])[:3])
    rng = f"{last}..HEAD" if last else "HEAD"
    log = git("log", rng, "--no-merges", "--format=%s%x1f%b%x1e")
    bump = 0  # 0 none, 1 patch, 2 minor, 3 major
    groups = {k: [] for k, _ in TITLES}
    for entry in filter(None, (e.strip() for e in log.split("\x1e"))):
        subject, _, body = entry.partition("\x1f")
        m = re.match(r"^(feat|fix|perf|refactor|revert|docs|ci|test|tests|chore|style|build)(\([^)]*\))?(!)?:\s*(.+)$",
                     subject, re.I)
        kind = m.group(1).lower() if m else "other"
        text = m.group(4) if m else subject
        # Only a real footer counts ("BREAKING CHANGE: ..." at the start of a line).
        breaking = bool(m and m.group(3)) or re.search(r"^BREAKING[ -]CHANGE:", body, re.M) is not None
        if kind in QUIET and not breaking:
            continue
        level = 3 if breaking else 2 if kind == "feat" else 1
        bump = max(bump, level)
        groups[kind if kind in groups else "other"].append(text[0].upper() + text[1:])
    if bump == 3:
        major, minor, patch = major + 1, 0, 0
    elif bump == 2:
        minor, patch = minor + 1, 0
    elif bump == 1:
        patch += 1
    version = f"{major}.{minor}.{patch}"
    print(f"version={version}")
    print(f"release={'true' if bump else 'false'}")
    if len(sys.argv) > 1:
        lines = []
        for key, title in TITLES:
            if groups[key]:
                lines.append(f"### {title}")
                lines += [f"- {t}" for t in groups[key]]
                lines.append("")
        lines.append("Play in the browser: https://vlx42.github.io/candy-marble/play/")
        lines.append("")
        lines.append("macOS: the app isn't notarized, so the first time right-click it and pick Open.")
        with open(sys.argv[1], "w") as fh:
            fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
