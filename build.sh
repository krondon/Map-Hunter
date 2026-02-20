#!/bin/bash

# 1. Descargar la versión estable de Flutter
git clone https://github.com/flutter/flutter.git -b stable

# 2. Agregar Flutter a las variables de entorno de Vercel
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Compilar el proyecto para web
flutter build web --release