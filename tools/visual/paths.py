"""Resolve untrusted catalog-relative paths without escaping the run directory."""
from pathlib import Path


def contained(root, relative):
    if not isinstance(relative, str) or not relative or "\\" in relative:
        raise ValueError("catalog path must be a nonempty portable relative string")
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError("catalog path must stay inside its directory")
    root = Path(root).resolve()
    candidate = (root / path).resolve()
    if not candidate.is_relative_to(root):
        raise ValueError("catalog path escapes directory through a symlink")
    return candidate


def image_directory(catalog_dir, manifest):
    return contained(catalog_dir, manifest.get("image_root", "."))
