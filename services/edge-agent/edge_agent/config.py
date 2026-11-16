"""Safe startup configuration for the future edge gateway."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class EdgeConfig:
    mode: str = "simulation"
    allow_device_writes: bool = False

    @classmethod
    def from_env(cls) -> "EdgeConfig":
        mode = os.getenv("BMS_EDGE_MODE", "simulation")
        if mode not in {"simulation", "connected"}:
            raise ValueError("BMS_EDGE_MODE must be simulation or connected")
        return cls(
            mode=mode,
            allow_device_writes=os.getenv("BMS_ALLOW_DEVICE_WRITES", "false").lower() == "true",
        )

    def assert_write_allowed(self) -> None:
        if self.mode != "connected" or not self.allow_device_writes:
            raise PermissionError("Physical device writes are disabled")
