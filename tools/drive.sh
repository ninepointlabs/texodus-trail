#!/bin/bash
# Talk to a running Texodus Trail over IPC: tools/drive.sh key space
exec quickshell ipc -p "$(cd "$(dirname "${BASH_SOURCE[0]}")/../app" && pwd)" call texodus "$@"
