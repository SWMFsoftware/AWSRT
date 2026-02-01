#!/usr/bin/env python3
import argparse
from pathlib import Path
import sys


def die(msg: str, code: int = 2) -> "None":
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Render a CME jobscript from a template and write it into the run directory."
    )
    ap.add_argument(
        "--swmf-dir",
        required=True,
        help="Path to SWMF directory containing the template jobscript.",
    )
    ap.add_argument(
        "--template",
        default="job_template.sh",
        help="Template filename inside SWMF_DIR (default: job_template.sh).",
    )
    ap.add_argument(
        "--run-dir",
        required=True,
        help="Full path to the CME run directory (RUNDIR).",
    )
    ap.add_argument(
        "--cme-event-dir",
        required=True,
        help="Full path to the CME event directory (contains CME.in and processed_CME.json).",
    )
    ap.add_argument(
        "--out-name",
        default="job_CME.sh",
        help="Output jobscript name to place inside RUN_DIR (default: job_CME.sh).",
    )
    args = ap.parse_args()

    swmf_dir = Path(args.swmf_dir).expanduser().resolve()
    run_dir = Path(args.run_dir).expanduser().resolve()
    cme_event_dir = Path(args.cme_event_dir).expanduser().resolve()

    template_path = swmf_dir / args.template
    if not template_path.is_file():
        die(f"Template not found: {template_path}")

    if not run_dir.is_dir():
        die(f"Run directory not found: {run_dir}")

    # Optional sanity checks (helpful)
    if not (cme_event_dir / "CME.in").is_file():
        die(f"Missing CME.in in event dir: {cme_event_dir}")
    if not (cme_event_dir / "processed_CME.json").is_file():
        die(f"Missing processed_CME.json in event dir: {cme_event_dir}")

    text = template_path.read_text()

    # Substitute placeholders
    rendered = (
        text.replace("{{RUNDIR}}", str(run_dir))
            .replace("{{CME_EVENT_DIR}}", str(cme_event_dir))
    )

    # Make sure placeholders were actually present (fail fast)
    if "{{RUNDIR}}" in rendered or "{{CME_EVENT_DIR}}" in rendered:
        die(
            "Template still contains placeholders. "
            "Ensure it includes {{RUNDIR}} and {{CME_EVENT_DIR}} exactly."
        )

    out_path = run_dir / args.out_name

    # Don't overwrite an existing jobscript unless you really want to
    if out_path.exists():
        die(f"Output already exists: {out_path} (choose a different --out-name or delete it)")

    out_path.write_text(rendered)
    out_path.chmod(0o750)

    print(str(out_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

