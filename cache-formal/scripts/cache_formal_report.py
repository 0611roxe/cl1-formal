#!/usr/bin/env python3
import argparse
import datetime
import hashlib
import json
import re
import sys
from pathlib import Path


def parse_sby(path):
    tasks = []
    mode = {}
    depth = {}
    top = {}
    macros = {}
    default_depth = ""
    section = None

    if not path.exists():
        return tasks, mode, depth, top, macros

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue

        if section == "tasks":
            tasks.append(line)
            continue

        if section == "options":
            m = re.match(r"([^:\s]+):\s*mode\s+(\S+)", line)
            if m:
                mode[m.group(1)] = m.group(2)
                continue
            m = re.match(r"([^:\s]+):\s*depth\s+(\S+)", line)
            if m:
                depth[m.group(1)] = m.group(2)
                continue
            m = re.match(r"depth\s+(\S+)", line)
            if m:
                default_depth = m.group(1)
                continue

        if section == "script":
            m = re.match(r"([^:\s]+):\s*prep\s+-top\s+(\S+)", line)
            if m:
                top[m.group(1)] = m.group(2)
                continue
            m = re.match(r"([^:\s]+):\s*read_verilog\b(.*)", line)
            if m:
                macros[m.group(1)] = ", ".join(re.findall(r"-D([A-Za-z0-9_]+)", m.group(2)))

    for task in tasks:
        depth.setdefault(task, default_depth)
        mode.setdefault(task, "")
        top.setdefault(task, "")
        macros.setdefault(task, "")

    return tasks, mode, depth, top, macros


def read_text(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def parse_files(path):
    files = []
    section = None
    if not path.exists():
        return files

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section == "files":
            files.append(line)
    return files


def input_digest(sby_config, rtl):
    digest = hashlib.sha256()
    digest.update(b"config\0")
    digest.update(sby_config.read_bytes())

    for entry in parse_files(sby_config):
        source = Path(entry)
        if source.name == "Cl1CacheFormal.sv":
            source = rtl
        digest.update(b"\0file\0")
        digest.update(entry.encode("utf-8"))
        digest.update(b"\0")
        digest.update(source.read_bytes())
    return digest.hexdigest()


def read_manifest(workdir):
    path = workdir / "cache_formal_manifest.json"
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def stamp_results(sby_dir, prefix, tasks, geometry, digest, stamp_after=None):
    manifest = {
        "geometry": geometry,
        "input_digest": digest,
    }
    for task in tasks:
        workdir = sby_dir / f"{prefix}_{task}"
        logfile = workdir / "logfile.txt"
        is_current_run = stamp_after is None or (
            logfile.exists() and logfile.stat().st_mtime >= stamp_after
        )
        if workdir.exists() and is_current_run:
            (workdir / "cache_formal_manifest.json").write_text(
                json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )


def extract_result(workdir):
    result = {
        "status": "MISSING",
        "elapsed": "",
        "elapsed_secs": "",
        "cover_step": "",
        "cover_trace": "",
        "cover_points": [],
        "note": "",
        "workdir": str(workdir),
    }

    if not workdir.exists():
        return result

    markers = [
        ("PASS", "PASS"),
        ("FAIL", "FAIL"),
        ("ERROR", "ERROR"),
        ("UNKNOWN", "UNKNOWN"),
    ]
    for filename, status in markers:
        if (workdir / filename).exists():
            result["status"] = status
            break
    else:
        result["status"] = "UNKNOWN"

    log = read_text(workdir / "logfile.txt")
    if "DONE (PASS" in log:
        result["status"] = "PASS"
    elif "DONE (FAIL" in log:
        result["status"] = "FAIL"
    elif "DONE (ERROR" in log:
        result["status"] = "ERROR"

    elapsed = re.findall(r"Elapsed clock time .*?:\s*([0-9:]+)\s*\((\d+)\)", log)
    if elapsed:
        result["elapsed"], result["elapsed_secs"] = elapsed[-1]

    cover = re.findall(r"reached cover statement .* step\s+(\d+)", log)
    if cover:
        result["cover_step"] = cover[-1]

    trace = re.findall(r"cover trace:\s*(\S+)", log)
    if trace:
        result["cover_trace"] = trace[-1]

    pass_text = read_text(workdir / "PASS")
    point_re = re.compile(
        r"cover trace:\s*(\S+\.vcd)\n"
        r"(?:cover trace:\s*\S+\.yw\n)?"
        r"\s*reached cover statement [^\n]* at ([^ ]+) step (\d+)"
    )
    result["cover_points"] = [
        {"trace": trace_file, "location": location, "step": step}
        for trace_file, location, step in point_re.findall(pass_text)
    ]

    if "successful proof by k-induction" in log:
        result["note"] = "k-induction"
    elif result["cover_step"]:
        result["note"] = "cover reached"

    return result


def collect_results(sby_dir, prefix, tasks, mode, depth, top, macros, geometry, digest):
    rows = []
    for task in tasks:
        workdir = sby_dir / f"{prefix}_{task}"
        result = extract_result(workdir)
        manifest = read_manifest(workdir)
        if result["status"] != "MISSING":
            if manifest is None:
                if result["status"] == "PASS":
                    result["status"] = "STALE"
                result["note"] = "missing input manifest"
            elif manifest.get("geometry") != geometry or manifest.get("input_digest") != digest:
                if result["status"] == "PASS":
                    result["status"] = "STALE"
                result["note"] = "input digest mismatch"
        result.update({
            "task": task,
            "mode": mode.get(task, ""),
            "depth": depth.get(task, ""),
            "top": top.get(task, ""),
            "macros": macros.get(task, ""),
        })
        rows.append(result)
    return rows


def table(rows, columns):
    widths = []
    for key, title in columns:
        widths.append(max(len(title), *(len(str(row.get(key, ""))) for row in rows)))

    def fmt(row):
        return "  ".join(str(row.get(key, "")).ljust(widths[i]) for i, (key, _) in enumerate(columns))

    header = "  ".join(title.ljust(widths[i]) for i, (_, title) in enumerate(columns))
    sep = "  ".join("-" * widths[i] for i in range(len(columns)))
    return "\n".join([header, sep] + [fmt(row) for row in rows])


def markdown_report(rows, sby_dir, sby_config, geometry, rtl, digest):
    now = datetime.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z")
    lines = [
        "# CL1 Cache Formal Report",
        "",
        f"Generated: `{now}`",
        "",
        "This report summarizes existing SymbiYosys workdirs. It does not run verification by itself.",
        "",
        "## Inputs",
        "",
        f"- Geometry: `{geometry}`",
        f"- SBY config: `{sby_config}`",
        f"- SBY workdir root: `{sby_dir}`",
        f"- RTL snapshot: `{rtl}`",
        f"- Input digest: `{digest}`",
        "",
        "## Results",
        "",
        "| Task | Mode | Depth | Top | Status | Time | Note |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]

    for row in rows:
        lines.append(
            "| {task} | {mode} | {depth} | {top} | {status} | {elapsed} | {note} |".format(
                task=row["task"],
                mode=row["mode"],
                depth=row["depth"],
                top=row["top"],
                status=row["status"],
                elapsed=row["elapsed"],
                note=row["note"],
            )
        )

    cover_rows = [row for row in rows if row["cover_step"] or row["cover_trace"]]
    if cover_rows:
        lines.extend(["", "## Cover", ""])
        for row in cover_rows:
            if row["cover_points"]:
                lines.append(f"`{row['task']}` reached {len(row['cover_points'])} cover point(s):")
                lines.append("")
                for point in row["cover_points"]:
                    lines.append(
                        f"- step `{point['step']}` at `{point['location']}`, trace `{point['trace']}`"
                    )
            else:
                if row["cover_step"]:
                    lines.append(f"- `{row['task']}` reached cover at step `{row['cover_step']}`.")
                if row["cover_trace"]:
                    lines.append(f"- `{row['task']}` trace: `{row['cover_trace']}`")

    missing = [row["task"] for row in rows if row["status"] == "MISSING"]
    if missing:
        lines.extend(["", "## Missing Tasks", ""])
        lines.append("No generated SBY result was found for:")
        lines.append("")
        for task in missing:
            lines.append(f"- `{task}`")

    lines.extend(["", "## Task Macros", ""])
    lines.append("| Task | Macros |")
    lines.append("| --- | --- |")
    for row in rows:
        lines.append(f"| {row['task']} | {row['macros']} |")

    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sby-dir", default="generated/sby")
    parser.add_argument("--prefix", default="cache_verify")
    parser.add_argument("--sby-config", default="cache_verify.sby")
    parser.add_argument("--geometry", default="unspecified")
    parser.add_argument("--rtl", default="generated/rtl/Cl1CacheFormal.sv")
    parser.add_argument("--stamp-tasks", nargs="+")
    parser.add_argument("--stamp-after", type=float)
    parser.add_argument("--require-tasks", nargs="+")
    parser.add_argument("--write")
    parser.add_argument("--status", action="store_true")
    args = parser.parse_args()

    sby_config = Path(args.sby_config)
    sby_dir = Path(args.sby_dir)
    rtl = Path(args.rtl)
    digest = input_digest(sby_config, rtl)
    tasks, mode, depth, top, macros = parse_sby(sby_config)
    if args.stamp_tasks:
        stamp_results(
            sby_dir,
            args.prefix,
            args.stamp_tasks,
            args.geometry,
            digest,
            args.stamp_after,
        )
    rows = collect_results(
        sby_dir, args.prefix, tasks, mode, depth, top, macros, args.geometry, digest
    )

    if args.status or not args.write:
        columns = [
            ("task", "Task"),
            ("mode", "Mode"),
            ("depth", "Depth"),
            ("status", "Status"),
            ("elapsed", "Time"),
            ("note", "Note"),
        ]
        print(table(rows, columns))

    if args.write:
        out = Path(args.write)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(
            markdown_report(rows, sby_dir, sby_config, args.geometry, args.rtl, digest),
            encoding="utf-8",
        )
        print(f"Wrote {out}")

    if args.require_tasks:
        by_task = {row["task"]: row["status"] for row in rows}
        failed = [task for task in args.require_tasks if by_task.get(task) != "PASS"]
        if failed:
            details = ", ".join(f"{task}={by_task.get(task, 'UNKNOWN_TASK')}" for task in failed)
            print(f"Required formal tasks are not PASS: {details}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
