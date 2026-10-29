#!/usr/bin/env python3
"""Fail-closed environment guard for UMBRA 0.8 VM operations.

This tool does not configure greetd, PAM, systemd, a seat, or boot. Its only
write mode bootstraps a root-owned marker after three independent VM checks
and an explicit operator confirmation.
"""

from __future__ import annotations

import argparse
import os
import stat
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


MARKER_PATH = Path("/etc/nocturne-greeter/real-login-vm-0.8")
MARKER_CONTENT = "NOCTURNE_REAL_LOGIN_VM=0.8\n"
ALLOWED_VIRTUALIZERS = frozenset({"kvm", "qemu"})


@dataclass(frozen=True)
class Evidence:
    virtualizer: str
    dmi_vendor: str
    dmi_product: str
    cpu_hypervisor_flag: bool
    marker_present: bool = False
    marker_regular: bool = False
    marker_symlink: bool = False
    marker_content: str = ""
    marker_uid: int | None = None
    marker_mode: int | None = None
    marker_parent_present: bool = True
    marker_parent_directory: bool = True
    marker_parent_symlink: bool = False
    marker_parent_uid: int | None = 0
    marker_parent_mode: int | None = 0o755


def vm_identity_errors(evidence: Evidence) -> list[str]:
    """Require VM detection, QEMU DMI identity, and a hypervisor CPU flag."""
    errors: list[str] = []
    virtualizer = evidence.virtualizer.strip().lower()
    if virtualizer not in ALLOWED_VIRTUALIZERS:
        errors.append("systemd-detect-virt --vm did not report kvm or qemu")

    dmi = f"{evidence.dmi_vendor} {evidence.dmi_product}".lower()
    if "qemu" not in dmi:
        errors.append("DMI vendor/product does not identify a QEMU guest")

    if not evidence.cpu_hypervisor_flag:
        errors.append("CPU does not expose the hypervisor flag")
    return errors


def marker_errors(evidence: Evidence) -> list[str]:
    errors: list[str] = []
    if not evidence.marker_parent_present:
        errors.append(f"VM marker directory is missing at {MARKER_PATH.parent}")
    if evidence.marker_parent_symlink or not evidence.marker_parent_directory:
        errors.append("VM marker directory is not a regular directory")
    if evidence.marker_parent_uid != 0:
        errors.append("VM marker directory is not owned by root")
    if evidence.marker_parent_mode is None or evidence.marker_parent_mode & 0o022:
        errors.append("VM marker directory is writable by group or others")
    if not evidence.marker_present:
        errors.append(f"VM confirmation marker is missing at {MARKER_PATH}")
        return errors
    if evidence.marker_symlink or not evidence.marker_regular:
        errors.append("VM confirmation marker is not a regular, non-symlink file")
    if evidence.marker_content != MARKER_CONTENT:
        errors.append("VM confirmation marker content is invalid")
    if evidence.marker_uid != 0:
        errors.append("VM confirmation marker is not owned by root")
    if evidence.marker_mode is None or evidence.marker_mode & 0o022:
        errors.append("VM confirmation marker is writable by group or others")
    return errors


def verification_errors(
    evidence: Evidence,
    *,
    confirmed: bool,
    require_marker: bool = True,
) -> list[str]:
    errors = vm_identity_errors(evidence)
    if require_marker:
        errors.extend(marker_errors(evidence))
    if not confirmed:
        errors.append("explicit --confirm-real-login-vm confirmation is required")
    return errors


def run_guarded_operation(
    evidence: Evidence,
    operation: Callable[[], None],
    *,
    confirmed: bool,
    require_marker: bool = True,
) -> tuple[bool, list[str]]:
    """Run an operation only when all requested checks pass."""
    errors = verification_errors(
        evidence, confirmed=confirmed, require_marker=require_marker
    )
    if errors:
        return False, errors
    operation()
    return True, []


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return ""


def _cpu_has_hypervisor_flag(path: Path = Path("/proc/cpuinfo")) -> bool:
    try:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.lower().startswith(("flags", "features")):
                if "hypervisor" in line.split():
                    return True
    except OSError:
        return False
    return False


def _marker_evidence(path: Path = MARKER_PATH) -> dict[str, object]:
    try:
        parent_info = path.parent.lstat()
    except OSError:
        return {"marker_present": False, "marker_parent_present": False}

    parent_symlink = stat.S_ISLNK(parent_info.st_mode)
    parent_directory = stat.S_ISDIR(parent_info.st_mode)
    parent_evidence = {
        "marker_parent_present": True,
        "marker_parent_directory": parent_directory,
        "marker_parent_symlink": parent_symlink,
        "marker_parent_uid": parent_info.st_uid,
        "marker_parent_mode": stat.S_IMODE(parent_info.st_mode),
    }
    if parent_symlink or not parent_directory:
        return {**parent_evidence, "marker_present": False}

    try:
        info = path.lstat()
    except OSError:
        return {**parent_evidence, "marker_present": False}

    is_symlink = stat.S_ISLNK(info.st_mode)
    is_regular = stat.S_ISREG(info.st_mode)
    content = ""
    if is_regular and not is_symlink:
        content = _read_text(path) + "\n"
    return {
        **parent_evidence,
        "marker_present": True,
        "marker_regular": is_regular,
        "marker_symlink": is_symlink,
        "marker_content": content,
        "marker_uid": info.st_uid,
        "marker_mode": stat.S_IMODE(info.st_mode),
    }


def collect_evidence() -> Evidence:
    try:
        result = subprocess.run(
            ["systemd-detect-virt", "--vm"],
            check=False,
            capture_output=True,
            text=True,
            timeout=3,
        )
        virtualizer = result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        virtualizer = ""

    dmi_root = Path("/sys/class/dmi/id")
    return Evidence(
        virtualizer=virtualizer,
        dmi_vendor=_read_text(dmi_root / "sys_vendor"),
        dmi_product=_read_text(dmi_root / "product_name"),
        cpu_hypervisor_flag=_cpu_has_hypervisor_flag(),
        **_marker_evidence(),
    )


def _write_marker_file(path: Path, *, expected_uid: int = 0) -> None:
    """Create the marker file without replacing any existing path."""
    parent = path.parent
    if parent.is_symlink():
        raise OSError(f"refusing symlinked marker directory: {parent}")
    parent.mkdir(mode=0o755, parents=False, exist_ok=True)
    parent_info = parent.lstat()
    if not stat.S_ISDIR(parent_info.st_mode) or stat.S_ISLNK(parent_info.st_mode):
        raise OSError(f"refusing unsafe marker directory: {parent}")
    if parent_info.st_uid != expected_uid or stat.S_IMODE(parent_info.st_mode) & 0o022:
        raise OSError(f"marker directory must be root-owned and not group/world writable: {parent}")

    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    flags |= getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags, 0o644)
    try:
        os.write(descriptor, MARKER_CONTENT.encode("utf-8"))
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def bootstrap_marker(
    path: Path = MARKER_PATH,
    *,
    evidence: Evidence,
    confirmed: bool,
) -> None:
    """Guard marker creation even when called outside the command-line path."""
    errors = verification_errors(evidence, confirmed=confirmed, require_marker=False)
    if errors:
        raise ValueError("; ".join(errors))
    if os.geteuid() != 0:
        raise PermissionError("marker bootstrap requires root inside the verified VM")
    _write_marker_file(path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--check", action="store_true", help="verify VM signals and marker (read-only)")
    action.add_argument("--bootstrap", action="store_true", help="create the marker after VM signal checks")
    parser.add_argument(
        "--confirm-real-login-vm",
        action="store_true",
        help="confirm that this is the disposable Nocturne 0.8 VM",
    )
    parser.add_argument("--dry-run", action="store_true", help="with --bootstrap, verify only and write nothing")
    args = parser.parse_args(argv)
    if args.dry_run and not args.bootstrap:
        parser.error("--dry-run is only valid with --bootstrap")

    evidence = collect_evidence()
    if args.check:
        errors = verification_errors(evidence, confirmed=args.confirm_real_login_vm)
        if errors:
            for error in errors:
                print(f"ABORT: {error}", file=sys.stderr)
            return 1
        print("VM verified: KVM/QEMU, QEMU DMI, hypervisor CPU flag, root-owned marker, explicit confirmation.")
        return 0

    # Bootstrap deliberately checks VM identity before it can create /etc files.
    errors = verification_errors(
        evidence,
        confirmed=args.confirm_real_login_vm,
        require_marker=False,
    )
    if errors:
        for error in errors:
            print(f"ABORT: {error}", file=sys.stderr)
        return 1
    if args.dry_run:
        print("VM signals verified; dry-run complete; no marker was written.")
        return 0
    if os.geteuid() != 0:
        print("ABORT: run this bootstrap as root inside the verified VM.", file=sys.stderr)
        return 1
    try:
        bootstrap_marker(path=MARKER_PATH, evidence=evidence, confirmed=args.confirm_real_login_vm)
    except (OSError, ValueError) as error:
        print(f"ABORT: could not create VM confirmation marker: {error}", file=sys.stderr)
        return 1
    print(f"Created root-owned VM confirmation marker at {MARKER_PATH}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
