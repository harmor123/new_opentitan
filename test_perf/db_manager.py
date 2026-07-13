"""SQLite 数据库管理：建表、增、删、查。"""

import sqlite3
import os
from datetime import datetime
from typing import Optional


class DBManager:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        parent = os.path.dirname(self.db_path) or "."
        os.makedirs(parent, exist_ok=True)
        con = sqlite3.connect(self.db_path)
        con.row_factory = sqlite3.Row
        con.execute("PRAGMA foreign_keys = ON")
        return con

    def _init_db(self):
        with self._connect() as con:
            con.executescript("""
                CREATE TABLE IF NOT EXISTS runs (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    version     TEXT    NOT NULL,
                    timestamp   TEXT    NOT NULL,
                    raw_log_path TEXT
                );

                CREATE TABLE IF NOT EXISTS metrics (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    run_id      INTEGER NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
                    operation   TEXT    NOT NULL,
                    cycles      INTEGER,
                    instructions INTEGER,
                    stalls      INTEGER,
                    stall_pct   REAL,
                    FOREIGN KEY (run_id) REFERENCES runs(id)
                );

                CREATE INDEX IF NOT EXISTS idx_runs_version   ON runs(version);
                CREATE INDEX IF NOT EXISTS idx_runs_timestamp ON runs(timestamp);
                CREATE INDEX IF NOT EXISTS idx_metrics_run_id ON metrics(run_id);
            """)
            # 扩展字段 (SQLite 3.35+ 支持 IF NOT EXISTS)
            for col, typ in [
                ("cycles_std", "INTEGER"),
                ("imem", "INTEGER"),
                ("dmem", "INTEGER"),
                ("instr_categories", "TEXT"),
                ("instr_freqs", "TEXT"),
                ("func_calls", "TEXT"),
                ("phase_breakdown", "TEXT"),
            ]:
                try:
                    con.execute(f"ALTER TABLE metrics ADD COLUMN {col} {typ}")
                except Exception:
                    pass  # column already exists

    # ── 增 ──
    def insert_run(self, version: str, log_path: str = "") -> int:
        ts = datetime.now().isoformat(timespec="seconds")
        with self._connect() as con:
            cur = con.execute(
                "INSERT INTO runs (version, timestamp, raw_log_path) VALUES (?, ?, ?)",
                (version, ts, log_path),
            )
            return cur.lastrowid

    def insert_metric(self, run_id: int, op: str, cycles: int = 0,
                      cycles_std: int = 0, instructions: int = 0,
                      stalls: int = 0, stall_pct: float = 0.0,
                      imem: int = 0, dmem: int = 0,
                      instr_categories: dict | None = None,
                      instr_freqs: dict | None = None,
                      func_calls: dict | None = None,
                      phase_breakdown: dict | None = None):
        import json
        cats_json = json.dumps(instr_categories) if instr_categories else "{}"
        freqs_json = json.dumps(instr_freqs) if instr_freqs else "{}"
        funcs_json = json.dumps(func_calls) if func_calls else "{}"
        pb_json = json.dumps(phase_breakdown) if phase_breakdown else "{}"
        with self._connect() as con:
            con.execute(
                "INSERT INTO metrics (run_id, operation, cycles, cycles_std, instructions, "
                "stalls, stall_pct, imem, dmem, instr_categories, instr_freqs, func_calls, "
                "phase_breakdown) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (run_id, op, cycles, cycles_std, instructions,
                 stalls, stall_pct, imem, dmem, cats_json, freqs_json, funcs_json, pb_json),
            )

    # ── 删 ──
    def delete_run(self, run_id: int) -> int:
        with self._connect() as con:
            cur = con.execute("DELETE FROM runs WHERE id = ?", (run_id,))
            return cur.rowcount

    def delete_runs_by_version(self, version: str, before: Optional[str] = None) -> int:
        with self._connect() as con:
            if before:
                cur = con.execute(
                    "DELETE FROM runs WHERE version = ? AND timestamp < ?",
                    (version, before),
                )
            else:
                cur = con.execute(
                    "DELETE FROM runs WHERE version = ?", (version,)
                )
            return cur.rowcount

    # ── 查 ──
    def get_latest_run_ids(self) -> dict[str, int]:
        """返回每个版本最新一次 run 的 ID。"""
        with self._connect() as con:
            rows = con.execute("""
                SELECT version, MAX(id) as run_id
                FROM runs GROUP BY version
            """).fetchall()
            return {r["version"]: r["run_id"] for r in rows}

    def get_metrics(self, run_id: int) -> list[dict]:
        with self._connect() as con:
            rows = con.execute(
                "SELECT * FROM metrics WHERE run_id = ? ORDER BY operation",
                (run_id,),
            ).fetchall()
            return [dict(r) for r in rows]

    def get_history(self, version: str) -> list[dict]:
        with self._connect() as con:
            rows = con.execute("""
                SELECT r.id AS run_id, r.timestamp, m.operation, m.cycles, m.instructions
                FROM runs r
                JOIN metrics m ON r.id = m.run_id
                WHERE r.version = ?
                ORDER BY r.timestamp ASC, m.operation
            """, (version,)).fetchall()
            return [dict(r) for r in rows]

    def get_all_versions(self) -> list[str]:
        with self._connect() as con:
            rows = con.execute("SELECT DISTINCT version FROM runs ORDER BY version").fetchall()
            return [r["version"] for r in rows]
