#!/bin/bash
# Deploy the mockup prompt to files.gxb.vc/ricky/mockup-prompt.md
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
gxb-files upload "$SCRIPT_DIR/Ricky mockup prompt.md" ricky/mockup-prompt.md
echo ""
echo "Deployed to: https://files.gxb.vc/ricky/mockup-prompt.md"
