"""Apply checks that pass before a lane-e patch lands and after it is in the tree."""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def git(*args, cwd=ROOT):
    return subprocess.run(
        ["git", *args], cwd=str(cwd), check=False, capture_output=True, text=True)


def forward_check(patch, cwd=ROOT):
    return git("apply", "--check", str(patch), cwd=cwd)


def reverse_check(patch, cwd=ROOT):
    return git("apply", "--reverse", "--check", str(patch), cwd=cwd)


def clean_head_check(patch):
    """git apply --check against a clean worktree of HEAD.

    Later patches can move the lines this patch changed, so neither a
    forward nor a reverse check on the stacked tree succeeds. HEAD is
    the base the patch was written for.
    """
    path = Path("/tmp/lane-e-clean-head")
    head = git("rev-parse", "HEAD")
    if head.returncode != 0:
        return head
    marker = path / ".clean-head"
    if not marker.is_file() or marker.read_text().strip() != head.stdout.strip():
        git("worktree", "remove", "--force", str(path))
        added = git("worktree", "add", "--detach", str(path), "HEAD")
        if added.returncode != 0:
            return added
        marker.write_text(head.stdout.strip() + "\n")
    return forward_check(patch, path)


def accepts(patch, cwd=ROOT):
    """The patch applies here, this tree already contains it, or it applies on a clean HEAD.

    A stacked tree can fail both the forward and reverse checks once a
    later patch edits the same lines. The clean worktree is that case.
    """
    forward = forward_check(patch, cwd)
    if forward.returncode == 0:
        return forward
    reverse = reverse_check(patch, cwd)
    if reverse.returncode == 0:
        return reverse
    if Path(cwd).resolve() == ROOT.resolve():
        return clean_head_check(patch)
    return forward
