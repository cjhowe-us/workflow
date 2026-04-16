"""Smoke tests for the lock-protocol shell scripts.

The `fake_gh` fixture shims a `gh` binary on PATH that mutates an in-memory
Project v2. We run the real shell scripts against it and assert behavior.
Runs entirely in the current Claude conversation — no cloud SDK, no API
key, no network.
"""
from __future__ import annotations

import datetime as dt
import subprocess
from pathlib import Path

import pytest

from conftest import PLUGIN_ROOT, SCRIPTS_DIR, read_item, seed_item

SH = lambda name: str(SCRIPTS_DIR / f"{name}.sh")
ITEM = "PVTI_test_1"
PROJECT = "PVT_test"
OWNER_FID = "F_lockOwner"
EXPIRY_FID = "F_lockExpiresAt"


def _iso_offset(minutes: int) -> str:
    return (dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=minutes)) \
        .strftime("%Y-%m-%dT%H:%M:%SZ")


def _run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kwargs)


def test_smoke_acquire_writes_both_fields(fake_gh):
    _, state_path = fake_gh
    seed_item(state_path, ITEM)
    expires = _iso_offset(15)

    cp = _run([
        SH("lock-acquire"),
        "--project", PROJECT, "--item", ITEM,
        "--owner-field", OWNER_FID, "--expiry-field", EXPIRY_FID,
        "--owner", "host1:sess1:worker1", "--expires-at", expires,
    ])
    assert cp.returncode == 0, cp.stderr

    item = read_item(state_path, ITEM)
    assert item["lock_owner"] == "host1:sess1:worker1"
    assert item["lock_expires_at"] == expires


def test_smoke_second_acquire_on_held_lock_races(fake_gh):
    _, state_path = fake_gh
    future = _iso_offset(15)
    seed_item(state_path, ITEM, owner="host1:sess1:worker1", expires_at=future)

    cp = _run([
        SH("lock-acquire"),
        "--project", PROJECT, "--item", ITEM,
        "--owner-field", OWNER_FID, "--expiry-field", EXPIRY_FID,
        "--owner", "host2:sess2:worker2", "--expires-at", _iso_offset(15),
    ])
    assert cp.returncode == 1, f"expected race exit 1, got {cp.returncode}\n{cp.stderr}"
    assert "raced" in cp.stderr

    item = read_item(state_path, ITEM)
    assert item["lock_owner"] == "host1:sess1:worker1"  # unchanged


def test_smoke_expired_lock_is_reclaimable(fake_gh):
    _, state_path = fake_gh
    past = _iso_offset(-15)  # 15 minutes ago
    seed_item(state_path, ITEM, owner="host1:sess1:worker1", expires_at=past)
    new_expires = _iso_offset(15)

    cp = _run([
        SH("lock-acquire"),
        "--project", PROJECT, "--item", ITEM,
        "--owner-field", OWNER_FID, "--expiry-field", EXPIRY_FID,
        "--owner", "host2:sess2:worker2", "--expires-at", new_expires,
    ])
    assert cp.returncode == 0, cp.stderr

    item = read_item(state_path, ITEM)
    assert item["lock_owner"] == "host2:sess2:worker2"
    assert item["lock_expires_at"] == new_expires


def test_smoke_release_clears_both_fields(fake_gh):
    _, state_path = fake_gh
    future = _iso_offset(15)
    seed_item(state_path, ITEM, owner="host1:sess1:worker1", expires_at=future)

    cp = _run([
        SH("lock-release"),
        "--project", PROJECT, "--item", ITEM,
        "--owner-field", OWNER_FID, "--expiry-field", EXPIRY_FID,
    ])
    assert cp.returncode == 0, cp.stderr

    item = read_item(state_path, ITEM)
    assert item["lock_owner"] == ""
    assert item["lock_expires_at"] == ""


def test_smoke_heartbeat_extends_expiry_without_touching_owner(fake_gh):
    _, state_path = fake_gh
    future = _iso_offset(5)
    seed_item(state_path, ITEM, owner="host1:sess1:worker1", expires_at=future)
    new_expires = _iso_offset(30)

    cp = _run([
        SH("lock-heartbeat"),
        "--project", PROJECT, "--item", ITEM,
        "--expiry-field", EXPIRY_FID, "--expires-at", new_expires,
        "--owner-field", OWNER_FID, "--expected-owner", "host1:sess1:worker1",
    ])
    assert cp.returncode == 0, cp.stderr

    item = read_item(state_path, ITEM)
    assert item["lock_owner"] == "host1:sess1:worker1"  # unchanged
    assert item["lock_expires_at"] == new_expires
