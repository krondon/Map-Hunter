#!/bin/bash
# 1. Descargar Flutter
git clone https://github.com/flutter/flutter.git -b stable /tmp/flutter

# 2. Marcar como directorio seguro
git config --global --add safe.directory /tmp/flutter

# 3. Agregar Flutter al PATH
export PATH="/tmp/flutter/bin:$PATH"

# 4. Compilar para web
flutter build web --release