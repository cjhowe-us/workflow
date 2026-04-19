"""presence vertex scheme — per-user active-session roster.

Replaces the ad-hoc `workflow-user-lock-<gh-user-id>` gist described in
`skills/workflow/references/multi-dev.md` with a first-class scheme. Backed
by `presence-gh-gist` storage.
"""

from __future__ import annotations

from typing import Any

from artifactlib.kinds import Kind
from artifactlib.scheme import Scheme, Subcommand
from pydantic import BaseModel, Field


class ActiveSession(BaseModel):
    machine_id: str
    session_id: str
    started_at: str
    last_heartbeat: str
    pid: int = 0


class PreviousSession(BaseModel):
    machine_id: str
    session_id: str
    started_at: str
    ended_at: str


class PresenceContent(BaseModel):
    active_machines: list[ActiveSession] = Field(default_factory=list)
    previous_machines: list[PreviousSession] = Field(default_factory=list)


class CreateIn(BaseModel):
    id: str = ""
    active_machines: list[ActiveSession] = Field(default_factory=list)
    previous_machines: list[PreviousSession] = Field(default_factory=list)


class CreateOut(BaseModel):
    uri: str
    created: bool = True


class GetIn(BaseModel):
    uri: str


class GetOut(BaseModel):
    uri: str
    content: PresenceContent


class UpdateIn(BaseModel):
    uri: str
    patch: dict[str, Any] = Field(default_factory=dict)


class UpdateOut(BaseModel):
    uri: str
    updated: bool


class StatusIn(BaseModel):
    uri: str


class StatusOut(BaseModel):
    uri: str
    status: str


class ListFilter(BaseModel):
    pass


class ListOut(BaseModel):
    entries: list[dict[str, Any]] = Field(default_factory=list)


SCHEME = Scheme(
    kind=Kind.VERTEX,
    name="presence",
    contract_version=1,
    content_model=PresenceContent,
    subcommands={
        "create": Subcommand(in_model=CreateIn, out_model=CreateOut, required=True),
        "get": Subcommand(in_model=GetIn, out_model=GetOut, required=True),
        "update": Subcommand(in_model=UpdateIn, out_model=UpdateOut, required=True),
        "status": Subcommand(in_model=StatusIn, out_model=StatusOut, required=True),
        "list": Subcommand(in_model=ListFilter, out_model=ListOut, required=True),
    },
)
