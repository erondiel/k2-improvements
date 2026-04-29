# prtouch-cleanup

Removes a stale `#*# [prtouch_v3]` block left behind in `printer.cfg`'s
`SAVE_CONFIG` section after the cartographer feature replaces the stock
prtouch_v3 probe.

## Why this is needed

The cartographer feature's `alter_config.py` removes the *active*
`[prtouch_v3]` section from `printer.cfg`, but the orphan
`#*# [prtouch_v3]` header inside the SAVE_CONFIG block at the bottom of
the file is not touched. Klipper still tries to validate that section on
restart and dies with:

```
Option 'step_swap_pin' in section 'prtouch_v3' must be specified
```

This is documented in the K2 Plus install gotchas (item 6).

## What this does

1. Backs up `printer.cfg` to `printer.cfg.before-prtouch-cleanup-<timestamp>`.
2. Deletes the line `#*# [prtouch_v3]` from `printer.cfg`.
3. Idempotent — re-running does nothing if no orphan header is present.

## When to run

- After installing the `cartographer` feature on stock K2 Plus 1.1.5.2 or
  1.1.3.13, **before** the next Klipper restart, OR
- Any time Klipper fails to start with the `step_swap_pin` error after a
  cartographer install.

## Activation

This is a config edit only. Klipper picks it up on the next restart;
no further action needed.
