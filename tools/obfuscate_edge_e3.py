#!/usr/bin/env python3
"""Backward-compatible edge-e3 entry point for the generic RTL packager."""

from __future__ import annotations

import sys

from package_obfuscated_rtl import main


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError) as error:
        raise SystemExit(f"error: {error}") from error
