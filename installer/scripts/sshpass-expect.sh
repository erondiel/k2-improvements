#!/bin/sh
# sshpass-equivalent using `expect` — for systems where the real sshpass
# binary isn't in the package manager's feed (notably the K2 Plus's
# Entware armv7-3.2 arch, which ships expect but not sshpass).
#
# Implements the sshpass(1) flags bootstrap.sh actually uses:
#   -p <password>   pass the password directly
#   -e              read password from $SSHPASS env var
#
# Other sshpass flags (-f / -d / -P / etc.) are not implemented — open
# an issue or PR if you need them.

set -u

PASSWORD=""
case "${1:-}" in
    -p) PASSWORD="${2:-}"; shift 2 ;;
    -e) PASSWORD="${SSHPASS:-}"; shift ;;
    -f|-d|-P|-h|-V)
        echo "ERROR: $1 not implemented in this expect-based sshpass replacement" >&2
        exit 1
        ;;
    *)
        echo "ERROR: usage: sshpass [-p password | -e] command [args...]" >&2
        exit 1
        ;;
esac

if [ -z "$PASSWORD" ]; then
    echo "ERROR: no password provided" >&2
    exit 1
fi

if [ "$#" -eq 0 ]; then
    echo "ERROR: no command provided" >&2
    exit 1
fi

# Write the expect program to a tmp file. Using a script file rather than
# `expect -c` because the `-c` mode doesn't populate $argv reliably across
# expect versions, and we need the SSH command + args available inside.
EXPECT_PROG=$(mktemp /tmp/sshpass-expect.XXXXXX.exp 2>/dev/null || echo "/tmp/sshpass-expect.$$.exp")
# Note: not using `trap ... EXIT` for cleanup because some shells (busybox
# ash on the K2 Plus) leak the trap's last-command exit code into $?,
# masking expect's real exit code on auth failure (5). Cleanup happens
# explicitly after the expect call, with $? preserved.

cat > "$EXPECT_PROG" <<'EXPECT_EOF'
#!/usr/bin/env expect -f
# $argv = the SSH command + its args, passed in by the shell wrapper.
# $env(SSHPASS_REPLACEMENT_PWD) = the password to feed.

log_user 1
set timeout 30

# Build the spawn command from $argv. eval is required so spawn sees
# the args as separate tokens, not one big string.
eval spawn -noecho $argv

# Count password attempts. If we send the same password and ssh re-prompts,
# the password was rejected — exit 5 (matching real sshpass(1) behavior on
# auth failure). Bootstrap.sh relies on this so `set -e` catches bad
# password input early.
set pw_attempts 0

expect {
    -nocase -re "password:" {
        incr pw_attempts
        if {$pw_attempts > 1} {
            puts stderr "sshpass-expect: authentication failed (password rejected)"
            exit 5
        }
        send "$env(SSHPASS_REPLACEMENT_PWD)\r"
        exp_continue
    }
    -nocase -re "passphrase" {
        incr pw_attempts
        if {$pw_attempts > 1} {
            puts stderr "sshpass-expect: authentication failed (passphrase rejected)"
            exit 5
        }
        send "$env(SSHPASS_REPLACEMENT_PWD)\r"
        exp_continue
    }
    # dropbear prompt: "Do you want to continue connecting? (y/n)" — answer "y"
    -nocase -re "\\(y/n\\)" {
        send "y\r"
        exp_continue
    }
    # OpenSSH prompt: "Are you sure you want to continue connecting (yes/no/[fingerprint])?" — answer "yes"
    -nocase -re "\\(yes/no" {
        send "yes\r"
        exp_continue
    }
    timeout {
        puts stderr "sshpass-expect: timed out waiting for command output"
        exit 1
    }
    eof {}
}

catch wait result
exit [lindex $result 3]
EXPECT_EOF

chmod +x "$EXPECT_PROG"

export SSHPASS_REPLACEMENT_PWD="$PASSWORD"
expect -f "$EXPECT_PROG" "$@"
EXIT_CODE=$?
rm -f "$EXPECT_PROG"
exit "$EXIT_CODE"
