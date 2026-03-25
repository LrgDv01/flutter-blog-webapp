#!/usr/bin/env bash

set -euo pipefail

FLUTTER_ROOT="$HOME/flutter"

if [ ! -d "$FLUTTER_ROOT" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "$FLUTTER_ROOT"
fi

"$FLUTTER_ROOT/bin/flutter" --version
"$FLUTTER_ROOT/bin/flutter" config --enable-web
"$FLUTTER_ROOT/bin/flutter" precache --web
"$FLUTTER_ROOT/bin/flutter" pub get
