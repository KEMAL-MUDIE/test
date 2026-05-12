#!/usr/bin/env bash
# Reap any leftover pc_load_test subscribers / launch wrappers from BOTH
# container workspaces. Use this when you've Ctrl-C'd a test and want to
# guarantee a clean state before re-running.
#
# Note: the patterns are kept inside this script (not passed on the command
# line) so `pkill -f` does not match its own caller's command line. Calling
# `sudo pkill -9 -f '...pc_load_test/...'` directly from a shell would
# match the shell wrapper and self-terminate.
set +e
sudo pkill -9 -f '/home/rbq/my_service/workspace/install/pc_load_test/'  2>/dev/null
sudo pkill -9 -f '/home/rbq/vln_service/workspace/install/pc_load_test/' 2>/dev/null
sudo pkill -9 -f 'load_test.launch.py'                                   2>/dev/null
sleep 1
remaining=$(pgrep -fa 'install/pc_load_test/' 2>/dev/null | grep -vE 'pgrep|cleanup\.sh' || true)
if [ -z "$remaining" ]; then
  echo "cleanup: clean"
else
  echo "cleanup: STILL ALIVE"
  echo "$remaining"
fi
exit 0
