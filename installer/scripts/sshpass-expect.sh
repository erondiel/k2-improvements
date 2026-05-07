#!/bin/sh
# sshpass-equivalent using `expect` — for systems where the real sshpass
# binary isn't in the package manager's feed (notably the K2 Plus's
# Entware armv7-3.2 arch).
#
# Implements the sshpass(1) flags we actually use in bootstrap.sh:
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
        echo "ERROR: usage: sshpass [-p password] [-e] command [args...]" >&2
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

# Pass the password to expect via env to avoid quoting it on the command line.
export SSHPASS_REPLACEMENT_PWD="$PASSWORD"

exec expect -c '
    log_user 1
    set timeout 30
    set cmd $argv
    eval spawn -noecho $cmd
    expect {
        -nocase -re "password:.*$" {
            send "$env(SSHPASS_REPLACEMENT_PWD)\r"
            exp_continue
        }
        -nocase -re "passphrase.*:.*$" {
            send "$env(SSHPASS_REPLACEMENT_PWD)\r"
            exp_continue
        }
        -nocase -re "are you sure you want to continue connecting.*\\?" {
            send "yes\r"
            exp_continue
        }
        -nocase -re "fingerprint.*\\(yes/no.*\\).*\\?" {
            send "yes\r"
            exp_continue
        }
        timeout {
            puts stderr "sshpass-expect: timed out waiting for password prompt or command output"
            exit 1
        }
        eof {}
    }
    catch wait result
    exit [lindex $result 3]
' -- "$@"
