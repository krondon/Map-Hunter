#!/bin/bash
# 1. Descargar SDK de Flutter (más rápido que clonar)
curl -sL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz | tar xJ -C /tmp

# 2. Agregar Flutter al PATH
export PATH="/tmp/flutter/bin:$PATH"

# 3. Compilar para web
flutter build web --release