"""presence-gh-gist storage — workflow presence via a per-user private gist.

Skeleton. Real impl shells out through ``artifactlib_gh.gh`` to create /
update a gist named ``workflow-user-lock-<gh-user-id>`` holding the
``PresenceContent`` JSON. The gist is private and per-user; multi-machine
presence coexists within the same gist's ``active_machines`` list.

Layout of fields matches ``artifact-schemes/presence/scheme.py``.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
_SCRIPTS = _HERE.parent.parent / "scripts"
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

from artifactlib import uri as uri_mod  # noqa: E402

GIST_NAME_TEMPLATE = "workflow-user-lock-{gh_user_id}"


def _id(uri_str: str) -> str:
    parsed = uri_mod.try_parse(uri_str)
    if parsed is None:
        raise ValueError(f"bad uri: {uri_str}")
    return parsed.path


def cmd_create(
    *, scheme: Any, adapter: dict[str, Any], input: Any, uri: str | None
) -> dict[str, Any]:
    raise NotImplementedError("presence-gh-gist create not implemented in this skeleton")


def cmd_get(
    *, scheme: Any, adapter: dict[str, Any], input: Any, uri: str | None
) -> dict[str, Any]:
    content = scheme.content_model().model_dump()
    return {"uri": uri or "", "content": content}


def cmd_update(
    *, scheme: Any, adapter: dict[str, Any], input: Any, uri: str | None
) -> dict[str, Any]:
    raise NotImplementedError("presence-gh-gist update not implemented in this skeleton")


def cmd_status(
    *, scheme: Any, adapter: dict[str, Any], input: Any, uri: str | None
) -> dict[str, Any]:
    return {"uri": uri or "", "status": "unknown"}


def cmd_list(
    *, scheme: Any, adapter: dict[str, Any], input: Any, uri: str | None
) -> dict[str, Any]:
    return {"entries": []}
