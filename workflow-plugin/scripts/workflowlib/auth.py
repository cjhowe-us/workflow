"""TTL-cached GitHub identity helper.

Wraps ``artifactlib_gh.gh.auth_status`` with a small on-disk cache stored
under ``$ARTIFACT_CONFIG_DIR/workflow/gh_auth.json``. Callers get sub-ms
lookups during multi-worker dispatch instead of re-shelling ``gh``.

Cache is invalidated by (a) TTL expiry, (b) explicit ``refresh()``, or
(c) the caller catching a downstream 401 and calling ``invalidate()``.
"""

from __future__ import annotations

import datetime
import json
import os
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Protocol

from artifactlib import xdg


class _AuthStatusLike(Protocol):
    authenticated: bool
    login: str | None
    scopes: list[str] | None
    hostname: str


def _load_shell_auth_status() -> Any:
    try:
        from artifactlib_gh.gh import auth_status

        return auth_status
    except ImportError:  # pragma: no cover — artifact-github-plugin not on path
        return None


_shell_auth_status: Any = _load_shell_auth_status()


DEFAULT_TTL_S = 3600


class AuthExpired(RuntimeError):
    """Raised when auth is required but no valid identity is available."""


@dataclass
class CachedAuth:
    authenticated: bool
    login: str | None
    scopes: list[str] | None
    fetched_at: str
    expires_at: str

    def is_expired(self, now: datetime.datetime | None = None) -> bool:
        now = now or datetime.datetime.now(datetime.UTC)
        try:
            exp = datetime.datetime.fromisoformat(self.expires_at)
        except ValueError:
            return True
        return now >= exp


def _cache_path() -> Path:
    p = xdg.resolve().config / "workflow" / "gh_auth.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def _ttl() -> int:
    try:
        return int(os.environ.get("WORKFLOW_GH_AUTH_TTL_S", str(DEFAULT_TTL_S)))
    except ValueError:
        return DEFAULT_TTL_S


def _read_cache() -> CachedAuth | None:
    p = _cache_path()
    if not p.is_file():
        return None
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        return CachedAuth(**data)
    except (OSError, json.JSONDecodeError, TypeError):
        return None


def _write_cache(entry: CachedAuth) -> None:
    _cache_path().write_text(json.dumps(asdict(entry), indent=2) + "\n", encoding="utf-8")


def _store(status: _AuthStatusLike) -> CachedAuth:
    now = datetime.datetime.now(datetime.UTC)
    exp = now + datetime.timedelta(seconds=_ttl())
    entry = CachedAuth(
        authenticated=status.authenticated,
        login=status.login,
        scopes=status.scopes,
        fetched_at=now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        expires_at=exp.strftime("%Y-%m-%dT%H:%M:%SZ"),
    )
    _write_cache(entry)
    return entry


def identity(*, hostname: str = "github.com") -> CachedAuth:
    """Return the current cached identity, refreshing if expired or missing."""
    cached = _read_cache()
    if cached and not cached.is_expired():
        return cached
    if _shell_auth_status is None:
        return CachedAuth(
            authenticated=False,
            login=None,
            scopes=None,
            fetched_at="",
            expires_at="",
        )
    status = _shell_auth_status(hostname=hostname)
    return _store(status)


def refresh(*, hostname: str = "github.com") -> CachedAuth:
    """Force a re-shell of `gh auth status` and update the cache."""
    invalidate()
    return identity(hostname=hostname)


def invalidate() -> None:
    p = _cache_path()
    try:
        p.unlink()
    except FileNotFoundError:
        pass


def require(*, hostname: str = "github.com") -> CachedAuth:
    """Return cached identity or raise ``AuthExpired`` with a `gh auth login` hint."""
    ident = identity(hostname=hostname)
    if not ident.authenticated:
        raise AuthExpired(
            f"Not authenticated to {hostname}. Run: gh auth login --hostname {hostname}"
        )
    return ident
