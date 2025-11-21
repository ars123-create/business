from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import json
from typing import Dict, Iterable, List


@dataclass(slots=True)
class ModeConfig:
    """Description of a single mode loaded from manifest.json."""

    id: str
    name: str
    entry: Path
    workdir: Path
    description: str = ""
    args: List[str] = field(default_factory=list)


class ModeRegistry:
    """Scans the modes directory and exposes metadata for each mode."""

    def __init__(self, modes_root: Path | None = None) -> None:
        project_root = Path(__file__).resolve().parent
        self._modes_dir = Path(modes_root) if modes_root else project_root / "modes"
        self._modes: Dict[str, ModeConfig] = {}
        self.reload()

    def reload(self) -> None:
        """Re-read all manifest.json files."""
        self._modes.clear()
        if not self._modes_dir.exists():
            return

        for manifest in sorted(self._modes_dir.glob("*/manifest.json")):
            try:
                data = json.loads(manifest.read_text(encoding="utf-8"))
            except Exception as exc:
                print(f"⚠️ Не удалось прочитать {manifest}: {exc}")
                continue

            mode_id = str(data.get("id") or "").strip()
            entry = str(data.get("entry") or "").strip()
            if not mode_id or not entry:
                print(f"⚠️ Пропускаю {manifest}: не хватает id или entry")
                continue

            workdir = manifest.parent
            entry_path = (workdir / entry).resolve()
            if not entry_path.exists():
                print(f"⚠️ Пропускаю {manifest}: файл {entry_path} не найден")
                continue

            args = data.get("args") or []
            if not isinstance(args, list):
                print(f"⚠️ Пропускаю {manifest}: поле args должно быть списком")
                continue

            description = str(data.get("description") or "").strip()
            self._modes[mode_id] = ModeConfig(
                id=mode_id,
                name=str(data.get("name") or mode_id),
                entry=entry_path,
                workdir=workdir,
                description=description,
                args=[str(a) for a in args],
            )

    def get(self, mode_id: str) -> ModeConfig | None:
        return self._modes.get(mode_id)

    def list_modes(self) -> Iterable[ModeConfig]:
        return self._modes.values()

    def __contains__(self, mode_id: str) -> bool:
        return mode_id in self._modes
