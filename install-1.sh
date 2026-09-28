#!/usr/bin/env bash
# install-1.sh — before 0.47, part 1 of the install. Now the whole install
# is ./install.sh: the base, then vikix add for the rest.
exec "$(dirname "$0")/install.sh" "$@"
