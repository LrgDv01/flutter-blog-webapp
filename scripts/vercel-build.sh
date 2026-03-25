#!/usr/bin/env bash

set -euo pipefail

FLUTTER_ROOT="$HOME/flutter"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo "Flutter SDK is missing. The install command did not complete successfully." >&2
  exit 1
fi

: "${SUPABASE_URL:?SUPABASE_URL is required for the Vercel build.}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required for the Vercel build.}"

"$FLUTTER_ROOT/bin/flutter" build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"
