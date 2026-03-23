#!/usr/bin/env bash
# Generate .buckconfig.local from the current environment.
# Run this once after activating your venv.

set -euo pipefail

PYTHON="$(which python3)"

echo "Using python: $PYTHON"

# Write .buckconfig.local with the python interpreter path.
# If you need additional local overrides (e.g. [bsv] libdir),
# add them to this file after running setup.sh.
cat > .buckconfig.local <<EOF
[python]
interpreter = $PYTHON
EOF

echo "Wrote .buckconfig.local with interpreter = $PYTHON"

pip install -r tools/requirements.txt
