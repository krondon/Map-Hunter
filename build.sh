
#!/bin/bash
# 1. Descargar Flutter
git clone https://github.com/flutter/flutter.git -b stable /tmp/flutter

# 2. Marcar como directorio seguro
git config --global --add safe.directory /tmp/flutter

# 3. Agregar Flutter al PATH
export PATH="/tmp/flutter/bin:$PATH"

# 4. Crear .env desde las variables de Vercel
cat <<EOF > .env
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
PAGO_PAGO_API_KEY=$PAGO_PAGO_API_KEY
PAGO_PAGO_API_URL=$PAGO_PAGO_API_URL
PAGO_PAGO_CANCEL_URL=$PAGO_PAGO_CANCEL_URL
PAGO_PAGO_WITHDRAW_URL=$PAGO_PAGO_WITHDRAW_URL
PAGO_PAGO_WEBHOOK_URL=$PAGO_PAGO_WEBHOOK_URL
EOF

# 5. Compilar para web
flutter build web --release
