# Fix `scone-td-build apply` missing `--version` flag

## Summary

- Add `--version ${SCONE_RUNTIME_VERSION}` to the `scone-td-build apply` command in the hello-world demo
- Regenerate all scripts from their READMEs to pick up pending README changes

## Problem

`scone-td-build apply` defaults to version `7.0.0-alpha.1` when `--version` is not specified.
In the hello-world demo, `register` ran with `--version ${SCONE_RUNTIME_VERSION}` (e.g. `6.1.0-rc.0`)
but `apply` ran with the default `7.0.0-alpha.1`. The two versions use different installer deb
formats, so apply pulled the wrong version of `scone-deb-pkgs` and failed with a binary extraction
error.

## Fix

Added `--version ${SCONE_RUNTIME_VERSION}` to the `scone-td-build apply` call in
`hello-world/README.md`. Scripts were regenerated from all READMEs to reflect this and
other pending README changes.

## Test plan

- [x] Ran `hello-world.sh --non-interactive` end-to-end on the scone-workshop cluster (SGX, `6.1.0-rc.0`)
- [x] Job completed and printed `Hello, world!` inside the SGX enclave
- [x] CI SGX jobs pass on the scone-td-build merge-train
