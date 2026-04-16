"""Fixtures for the coordinator test suite.

`fake_gh` — writes a Python shim on PATH that mimics a small subset of the
`gh` CLI against an in-memory Project v2. The tests run offline and live
entirely inside a single Claude conversation; no cloud SDK, no API key.
"""
from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import textwrap
from pathlib import Path

import pytest

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = PLUGIN_ROOT / "scripts"


# ---------------------------------------------------------------------------
# Smoke fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def fake_gh(tmp_path, monkeypatch):
    """Install a fake `gh` binary that reads/writes a JSON state file.

    The state file models a single Project v2 with N items, each having the
    two Text fields `lock_owner` and `lock_expires_at`. Mutations emitted by
    `lock-acquire.sh` / `lock-release.sh` / `lock-heartbeat.sh` are parsed
    and applied to this in-memory state. Queries read from it.

    Yields the `(bin_dir, state_path)` pair so tests can read the state back.
    """
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()

    state_path = tmp_path / "project-state.json"
    state_path.write_text(json.dumps({
        "fields": {
            "lock_owner": "F_lockOwner",
            "lock_expires_at": "F_lockExpiresAt",
        },
        "items": {},
    }))

    fake_gh_py = bin_dir / "gh"
    fake_gh_py.write_text(textwrap.dedent(f"""
        #!/usr/bin/env python3
        import json, os, re, sys
        STATE = {json.dumps(str(state_path))!s}

        def load(): return json.loads(open(STATE).read())
        def save(s): open(STATE, "w").write(json.dumps(s, indent=2))

        def flag(name):
            if name in sys.argv:
                i = sys.argv.index(name); return sys.argv[i + 1]
            return None

        args = sys.argv[1:]
        if args[:2] != ["api", "graphql"]:
            sys.stderr.write(f"fake gh: unsupported subcommand: {{args!r}}\\n")
            sys.exit(2)

        query = flag("-f").split("=", 1)[1] if flag("-f") else ""
        # Real gh accepts many -f; grab them all as a dict.
        params = {{}}
        for i, tok in enumerate(sys.argv):
            if tok == "-f" and i + 1 < len(sys.argv):
                k, _, v = sys.argv[i + 1].partition("=")
                params[k] = v

        q = params.get("query", "")
        state = load()

        # --- Read fields on project -----------------------------------------
        if "fields(first:" in q and "ProjectV2Field" in q:
            print(json.dumps({{
                "data": {{"node": {{"fields": {{"nodes": [
                    {{"id": fid, "name": name}}
                    for name, fid in state["fields"].items()
                ]}}}}}}
            }}))
            sys.exit(0)

        # --- Read one item's field values -----------------------------------
        if "ProjectV2Item" in q and "fieldValues" in q and "project" not in params:
            item_id = params.get("item")
            itm = state["items"].setdefault(item_id, {{"lock_owner": "", "lock_expires_at": ""}})
            print(json.dumps({{
                "data": {{"node": {{"fieldValues": {{"nodes": [
                    {{"text": itm["lock_owner"], "field": {{"name": "lock_owner"}}}},
                    {{"text": itm["lock_expires_at"], "field": {{"name": "lock_expires_at"}}}},
                ]}}}}}}
            }}))
            sys.exit(0)

        # --- List project items (full scan) ---------------------------------
        if "items(first:" in q and "ProjectV2Item" not in q.split("items(first:")[0]:
            nodes = []
            for iid, fields in state["items"].items():
                # smoke harness assumes PR items by default
                c = fields.get("_content") or {{
                    "__typename": "PullRequest",
                    "number": int(iid.split(":")[-1]) if ":" in iid else 1,
                    "state": "OPEN",
                    "isDraft": True,
                    "repository": {{"nameWithOwner": "test/repo"}},
                    "headRefName": fields.get("_branch") or "coordinator/test",
                    "labels": {{"nodes": [{{"name": "phase:specify"}}]}},
                }}
                nodes.append({{
                    "id": iid,
                    "content": c,
                    "fieldValues": {{"nodes": [
                        {{"__typename": "ProjectV2ItemFieldTextValue",
                         "text": fields["lock_owner"], "field": {{"name": "lock_owner"}}}},
                        {{"__typename": "ProjectV2ItemFieldTextValue",
                         "text": fields["lock_expires_at"], "field": {{"name": "lock_expires_at"}}}},
                    ]}},
                }})
            print(json.dumps({{
                "data": {{"node": {{"items": {{
                    "pageInfo": {{"hasNextPage": False, "endCursor": None}},
                    "nodes": nodes,
                }}}}}}
            }}))
            sys.exit(0)

        # --- Mutation: updateProjectV2ItemFieldValue (one or two aliases) ---
        if "updateProjectV2ItemFieldValue" in q:
            item_id = params.get("item")
            itm = state["items"].setdefault(item_id, {{"lock_owner": "", "lock_expires_at": ""}})
            owner_fid  = state["fields"]["lock_owner"]
            expiry_fid = state["fields"]["lock_expires_at"]
            # The mutation body references $ownerField / $expiryField; look up which
            # field ID was bound to which variable and apply the corresponding value.
            # Missing `owner`/`expiry` param => the query body carries
            # `value: {{ text: "" }}` inline, i.e. this is a clear mutation.
            if params.get("ownerField") == owner_fid:
                itm["lock_owner"] = params.get("owner", "")
            if params.get("expiryField") == expiry_fid:
                itm["lock_expires_at"] = params.get("expiry", "")
            save(state)
            print(json.dumps({{"data": {{"clientMutationId": None}}}}))
            sys.exit(0)

        sys.stderr.write(f"fake gh: unhandled graphql query: {{q[:120]!r}}\\n")
        sys.exit(3)
    """).lstrip())
    fake_gh_py.chmod(fake_gh_py.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    old_path = os.environ.get("PATH", "")
    monkeypatch.setenv("PATH", f"{bin_dir}:{old_path}")
    yield bin_dir, state_path


def seed_item(state_path: Path, item_id: str, *, owner: str = "", expires_at: str = "",
              content: dict | None = None) -> None:
    state = json.loads(state_path.read_text())
    state["items"][item_id] = {
        "lock_owner": owner,
        "lock_expires_at": expires_at,
        "_content": content,
    }
    state_path.write_text(json.dumps(state, indent=2))


def read_item(state_path: Path, item_id: str) -> dict:
    return json.loads(state_path.read_text())["items"].get(item_id, {})


