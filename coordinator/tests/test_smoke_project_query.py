"""Smoke test: project-query.sh parses the fake gh's response into the
documented record shape — PRs only, phase extracted from labels.
"""
from __future__ import annotations

import json
import subprocess

from conftest import SCRIPTS_DIR, seed_item

PROJECT = "PVT_test"


def test_smoke_project_query_emits_pr_records_with_phase(fake_gh):
    _, state_path = fake_gh

    seed_item(
        state_path,
        "PVTI_1",
        owner="",
        expires_at="",
        content={
            "__typename": "PullRequest",
            "number": 101,
            "state": "OPEN",
            "isDraft": True,
            "repository": {"nameWithOwner": "cjhowe-us/coordinator-sandbox"},
            "headRefName": "coordinator/specify-login",
            "labels": {"nodes": [{"name": "phase:specify"}]},
        },
    )
    seed_item(
        state_path,
        "PVTI_2",
        owner="host1:sess1:worker1",
        expires_at="2099-01-01T00:00:00Z",
        content={
            "__typename": "PullRequest",
            "number": 102,
            "state": "OPEN",
            "isDraft": True,
            "repository": {"nameWithOwner": "cjhowe-us/coordinator-sandbox"},
            "headRefName": "coordinator/design-tokens",
            "labels": {"nodes": [{"name": "phase:design"}, {"name": "area:auth"}]},
        },
    )

    cp = subprocess.run(
        [str(SCRIPTS_DIR / "project-query.sh"), PROJECT],
        capture_output=True, text=True,
    )
    assert cp.returncode == 0, cp.stderr

    records = [json.loads(line) for line in cp.stdout.strip().splitlines()]
    assert len(records) == 2

    by_num = {r["number"]: r for r in records}

    r1 = by_num[101]
    assert r1["phase"] == "specify"
    assert r1["state"] == "open"
    assert r1["is_draft"] is True
    assert r1["lock_owner"] == ""
    assert r1["lock_expires_at"] == ""
    assert r1["head_ref_name"] == "coordinator/specify-login"

    r2 = by_num[102]
    assert r2["phase"] == "design"
    assert r2["lock_owner"] == "host1:sess1:worker1"
    assert r2["lock_expires_at"] == "2099-01-01T00:00:00Z"
