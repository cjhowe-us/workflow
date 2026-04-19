"""First-run seed — bind storage backends and mark the workspace/user
as initialized.

Called by the `default` workflow's `seed` step before `interpret`. Detects
whether the current repo is on GitHub, writes default storage bindings, and
sets ``workflow.initialized`` flags so subsequent ``/workflow`` invocations
skip this path.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import cast

from artifactlib import xdg

from . import auth


@dataclass
class RepoFacts:
    is_git: bool
    on_github: bool
    remote_url: str | None
    repo_slug: str | None  # e.g. "owner/repo"
    root: Path


@dataclass
class SeedOutcome:
    already_initialized: bool
    on_github: bool
    workspace_path: Path
    user_path: Path
    workspace_prefs: dict[str, object]
    user_prefs: dict[str, object]
    next_prompts: list[str]  # human gates the orchestrator should surface


def _repo_root(start: Path) -> Path | None:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=str(start),
            text=True,
            capture_output=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return Path(out.stdout.strip()) if out.stdout.strip() else None


def _origin_url(repo: Path) -> str | None:
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "remote", "get-url", "origin"],
            text=True,
            capture_output=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    url = out.stdout.strip()
    return url or None


def _github_slug(url: str) -> str | None:
    for prefix in ("git@github.com:", "ssh://git@github.com/", "https://github.com/"):
        if url.startswith(prefix):
            tail = url[len(prefix) :]
            if tail.endswith(".git"):
                tail = tail[:-4]
            return tail or None
    return None


def detect_repo(cwd: Path | None = None) -> RepoFacts:
    start = cwd or Path.cwd()
    root = _repo_root(start)
    if root is None:
        return RepoFacts(
            is_git=False, on_github=False, remote_url=None, repo_slug=None, root=start
        )
    url = _origin_url(root)
    slug = _github_slug(url) if url else None
    return RepoFacts(
        is_git=True,
        on_github=slug is not None,
        remote_url=url,
        repo_slug=slug,
        root=root,
    )


def _workspace_id(root: Path) -> str:
    digest = hashlib.sha256(str(root.resolve()).encode("utf-8")).hexdigest()[:16]
    return f"workspace/{digest}"


def _prefs_path(prefs_id: str) -> Path:
    return xdg.resolve().config / "preferences" / f"{prefs_id}.json"


def _read_prefs(prefs_id: str) -> dict[str, object]:
    p = _prefs_path(prefs_id)
    if not p.is_file():
        return {}
    try:
        data: dict[str, object] = json.loads(p.read_text(encoding="utf-8"))
        return data
    except (OSError, json.JSONDecodeError):
        return {}


def _write_prefs(prefs_id: str, data: dict[str, object]) -> Path:
    p = _prefs_path(prefs_id)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return p


def _is_initialized(prefs: dict[str, object]) -> bool:
    extra = prefs.get("extra")
    if not isinstance(extra, dict):
        return False
    return bool(cast(dict[str, object], extra).get("workflow_initialized"))


def _merge(prefs: dict[str, object], patch: dict[str, object]) -> dict[str, object]:
    out = dict(prefs)
    extra_current = out.get("extra")
    extra = dict(extra_current) if isinstance(extra_current, dict) else {}
    extra.update(patch)
    out["extra"] = extra
    return out


GH_DEFAULTS = {
    "storage_state": "execution-gh-pr",
    "storage_lock": "gh-gist",
    "overlay_dependencies": "gh-issue",
}

# Every seeded backend goes through a confirmation question. ``None`` means the
# orchestrator still needs to ask; a string is the user's chosen value;
# ``""`` (empty) means explicitly disabled (pluggable + optional).
BackendChoices = dict[str, str | None]


def default_choices(on_github: bool) -> BackendChoices:
    if on_github:
        return {k: None for k in GH_DEFAULTS}
    return {"storage_state": None, "storage_lock": None, "overlay_dependencies": None}


def seed(
    *,
    cwd: Path | None = None,
    choices: BackendChoices | None = None,
) -> SeedOutcome:
    """Write default preferences if not already initialized.

    ``choices`` is a mapping of backend key → chosen value. Each of
    ``storage_state`` (execution state), ``storage_lock`` (lock/presence), and
    ``overlay_dependencies`` (dependency graph overlay) is pluggable and
    optional — the orchestrator asks the user to confirm each before seeding.
    A ``None`` entry means the orchestrator still owes a question; the outcome's
    ``next_prompts`` lists those keys along with the default to offer. An
    empty-string entry (``""``) means the user declined that backend.
    """
    facts = detect_repo(cwd)
    workspace_id = _workspace_id(facts.root)
    user_prefs = _read_prefs("user")
    workspace_prefs = _read_prefs(workspace_id)

    if _is_initialized(user_prefs) and _is_initialized(workspace_prefs):
        return SeedOutcome(
            already_initialized=True,
            on_github=facts.on_github,
            workspace_path=_prefs_path(workspace_id),
            user_path=_prefs_path("user"),
            workspace_prefs=workspace_prefs,
            user_prefs=user_prefs,
            next_prompts=[],
        )

    if facts.on_github:
        auth.require()

    resolved = dict(choices) if choices else default_choices(facts.on_github)
    next_prompts = [k for k, v in resolved.items() if v is None]
    if next_prompts:
        return SeedOutcome(
            already_initialized=False,
            on_github=facts.on_github,
            workspace_path=_prefs_path(workspace_id),
            user_path=_prefs_path("user"),
            workspace_prefs=workspace_prefs,
            user_prefs=user_prefs,
            next_prompts=next_prompts,
        )

    workspace_patch: dict[str, object] = {
        "workflow_initialized": True,
        "repo_facts": asdict(facts) | {"root": str(facts.root)},
    }
    user_patch: dict[str, object] = {"workflow_initialized": True}

    if resolved.get("storage_state"):
        workspace_patch["storage_state"] = resolved["storage_state"]
    if resolved.get("storage_lock"):
        user_patch["storage_lock"] = resolved["storage_lock"]
    if resolved.get("overlay_dependencies"):
        workspace_patch["overlay_dependencies"] = resolved["overlay_dependencies"]

    user_prefs = _merge(user_prefs, user_patch)
    workspace_prefs = _merge(workspace_prefs, workspace_patch)
    user_path = _write_prefs("user", user_prefs)
    workspace_path = _write_prefs(workspace_id, workspace_prefs)

    return SeedOutcome(
        already_initialized=False,
        on_github=facts.on_github,
        workspace_path=workspace_path,
        user_path=user_path,
        workspace_prefs=workspace_prefs,
        user_prefs=user_prefs,
        next_prompts=[],
    )
