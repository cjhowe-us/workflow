"""Tests for workflowlib.seed — first-run preference seeding."""

from __future__ import annotations

import json
import subprocess

import pytest
from workflowlib import auth, seed


class _FakeStatus:
    def __init__(self, authenticated: bool = True, login: str = "alice") -> None:
        self.authenticated = authenticated
        self.login = login
        self.scopes = ["repo"] if authenticated else None
        self.hostname = "github.com"


@pytest.fixture
def authed(tmp_worktree, monkeypatch):
    monkeypatch.setattr(
        auth, "_shell_auth_status", lambda hostname="github.com": _FakeStatus(True)
    )
    return tmp_worktree


def _set_remote(path, url: str) -> None:
    subprocess.run(
        ["git", "-C", str(path), "remote", "add", "origin", url],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def test_detect_github_via_https(authed):
    _set_remote(authed, "https://github.com/alice/repo.git")
    facts = seed.detect_repo()
    assert facts.on_github
    assert facts.repo_slug == "alice/repo"


def test_detect_github_via_ssh(authed):
    _set_remote(authed, "git@github.com:alice/repo.git")
    facts = seed.detect_repo()
    assert facts.on_github
    assert facts.repo_slug == "alice/repo"


def test_detect_non_github(authed):
    _set_remote(authed, "git@gitlab.com:alice/repo.git")
    facts = seed.detect_repo()
    assert not facts.on_github
    assert facts.repo_slug is None


def test_seed_returns_next_prompts_when_no_choices(authed):
    _set_remote(authed, "https://github.com/alice/repo.git")
    outcome = seed.seed()
    assert not outcome.already_initialized
    assert set(outcome.next_prompts) == {
        "storage_state",
        "storage_lock",
        "overlay_dependencies",
    }


def test_seed_writes_accepted_and_omits_declined(authed):
    _set_remote(authed, "https://github.com/alice/repo.git")
    choices: seed.BackendChoices = {
        "storage_state": "execution-gh-pr",
        "storage_lock": "gh-gist",
        "overlay_dependencies": "",  # declined
    }
    outcome = seed.seed(choices=choices)

    assert outcome.next_prompts == []
    user_extra = outcome.user_prefs["extra"]
    workspace_extra = outcome.workspace_prefs["extra"]

    assert user_extra["workflow_initialized"] is True
    assert user_extra["storage_lock"] == "gh-gist"
    assert workspace_extra["workflow_initialized"] is True
    assert workspace_extra["storage_state"] == "execution-gh-pr"
    assert "overlay_dependencies" not in workspace_extra


def test_seed_rerun_is_noop(authed):
    _set_remote(authed, "https://github.com/alice/repo.git")
    choices: seed.BackendChoices = {
        "storage_state": "execution-gh-pr",
        "storage_lock": "gh-gist",
        "overlay_dependencies": "gh-issue",
    }
    seed.seed(choices=choices)
    again = seed.seed(choices=choices)

    assert again.already_initialized is True


def test_seed_non_github_defaults_all_unset(authed):
    _set_remote(authed, "git@gitlab.com:alice/repo.git")
    outcome = seed.seed()
    assert set(outcome.next_prompts) == {
        "storage_state",
        "storage_lock",
        "overlay_dependencies",
    }


def test_seed_requires_auth_on_github(tmp_worktree, monkeypatch):
    _set_remote(tmp_worktree, "https://github.com/alice/repo.git")
    monkeypatch.setattr(
        auth, "_shell_auth_status", lambda hostname="github.com": _FakeStatus(False, login="")
    )
    with pytest.raises(auth.AuthExpired):
        seed.seed(
            choices={
                "storage_state": "execution-gh-pr",
                "storage_lock": "gh-gist",
                "overlay_dependencies": "",
            }
        )


def test_seed_writes_prefs_files_on_disk(authed):
    _set_remote(authed, "https://github.com/alice/repo.git")
    outcome = seed.seed(
        choices={
            "storage_state": "execution-gh-pr",
            "storage_lock": "gh-gist",
            "overlay_dependencies": "gh-issue",
        }
    )
    user_data = json.loads(outcome.user_path.read_text())
    workspace_data = json.loads(outcome.workspace_path.read_text())
    assert user_data["extra"]["storage_lock"] == "gh-gist"
    assert workspace_data["extra"]["storage_state"] == "execution-gh-pr"
    assert workspace_data["extra"]["overlay_dependencies"] == "gh-issue"
