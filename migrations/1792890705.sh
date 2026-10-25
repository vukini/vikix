#!/usr/bin/env bash
# Why: 55-hardware now installs udev's Thunderbolt drives rule,
# config/udev/70-vikix-thunderbolt.rules. A USB4 SSD (a Corsair EX400U on
# the ROG Flow Z13, 2026-10-25) comes through Thunderbolt, not as USB
# storage, and the kernel leaves it waiting to be authorized: no disk
# appeared and nothing mounted. The rule authorizes it as it arrives when
# the IOMMU protects memory, and makes the disk behind it a drive udiskie
# mounts. vikix update doesn't re-run that stage, so machines already
# installed get it here. The stage checks first: a machine that has the
# file does nothing.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

bash "$VIKIX_DIR/install/55-hardware.sh"
