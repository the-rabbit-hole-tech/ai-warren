#!/usr/bin/env bash
# The scrub gate and the generic guard share one private-terms folder: ~/.config/warren/terms by
# default, with SCRUB_TERMS_DIR (gate) and WARREN_TERMS_DIR (guard) as overrides.
source "$(dirname "$0")/../assert.sh"
GATE="$PLUGIN/git-hooks/scrub/gate.py"
dir() { env -u SCRUB_TERMS_DIR HOME=/nohome python3 -I -c "
import importlib.util,sys
s=importlib.util.spec_from_file_location('gate','$GATE'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(m.TERMS_DIR)"; }
out=$(dir); rc=$?
expect 0 "the gate loads"
assert_default=$(printf '%s' "$out" | tail -1)
[ "$assert_default" = "/nohome/.config/warren/terms" ] && ok "the gate's default folder is ~/.config/warren/terms" || bad "gate default (got $assert_default)"
out=$(SCRUB_TERMS_DIR=/elsewhere python3 -I -c "
import importlib.util
s=importlib.util.spec_from_file_location('gate','$GATE'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(m.TERMS_DIR)" | tail -1)
[ "$out" = "/elsewhere" ] && ok "SCRUB_TERMS_DIR overrides it" || bad "override (got $out)"
finish
