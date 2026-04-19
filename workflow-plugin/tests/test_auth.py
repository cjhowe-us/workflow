"""Tests for workflowlib.auth TTL cache + require semantics."""

from __future__ import annotations

import datetime
import json

import pytest
from workflowlib import auth


class _FakeStatus:
    def __init__(self, authenticated: bool, login: str | None = "alice") -> None:
        self.authenticated = authenticated
        self.login = login
        self.scopes = ["repo", "read:org"] if authenticated else None
        self.hostname = "github.com"


@pytest.fixture
def isolated_cache(tmp_worktree, monkeypatch):
    monkeypatch.setenv("WORKFLOW_GH_AUTH_TTL_S", "3600")
    return tmp_worktree


def test_identity_shells_on_miss_and_caches(isolated_cache, monkeypatch):
    calls = []

    def fake(hostname: str = "github.com"):
        calls.append(hostname)
        return _FakeStatus(authenticated=True)

    monkeypatch.setattr(auth, "_shell_auth_status", fake)

    first = auth.identity()
    second = auth.identity()

    assert first.authenticated
    assert first.login == "alice"
    assert len(calls) == 1, "second call should be a cache hit"
    assert second.login == first.login


def test_identity_refresh_bypasses_cache(isolated_cache, monkeypatch):
    calls = []

    def fake(hostname: str = "github.com"):
        calls.append(hostname)
        return _FakeStatus(authenticated=True)

    monkeypatch.setattr(auth, "_shell_auth_status", fake)

    auth.identity()
    auth.refresh()

    assert len(calls) == 2


def test_require_raises_when_unauth(isolated_cache, monkeypatch):
    monkeypatch.setattr(
        auth, "_shell_auth_status", lambda hostname="github.com": _FakeStatus(False, login=None)
    )

    with pytest.raises(auth.AuthExpired):
        auth.require()


def test_cache_expiry_triggers_reshell(isolated_cache, monkeypatch):
    calls = []

    def fake(hostname: str = "github.com"):
        calls.append(hostname)
        return _FakeStatus(authenticated=True)

    monkeypatch.setattr(auth, "_shell_auth_status", fake)

    auth.identity()

    # Manually age the cache past the TTL.
    cache = auth._cache_path()
    data = json.loads(cache.read_text())
    past = datetime.datetime.now(datetime.UTC) - datetime.timedelta(hours=2)
    data["expires_at"] = past.strftime("%Y-%m-%dT%H:%M:%SZ")
    cache.write_text(json.dumps(data))

    auth.identity()

    assert len(calls) == 2
