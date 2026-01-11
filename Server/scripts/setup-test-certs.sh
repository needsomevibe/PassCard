#!/bin/bash

# ===========================================
# Скрипт создания тестовых сертификатов
# ===========================================
# 
# ⚠️ ВНИМАНИЕ: Пассы с этими сертификатами
#    НЕ БУДУТ работать в Apple Wallet!
#
# Используйте только для тестирования API.
# Для реального использования нужны сертификаты
# от Apple Developer Program.
#
# ===========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/../certificates"

echo "🔐 Creating test certificates..."
echo "   ⚠️  These are for development only!"
echo ""

# Создаём директорию
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Проверяем, есть ли уже сертификаты
if [ -f "signerCert.pem" ] && [ -f "signerKey.pem" ] && [ -f "WWDR.pem" ]; then
    echo "⚠️  Certificates already exist!"
    read -p "   Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "   Cancelled."
        exit 0
    fi
fi

# Создаём self-signed сертификат
echo "📝 Generating self-signed certificate..."
openssl req -x509 -newkey rsa:2048 \
    -keyout signerKey.pem \
    -out signerCert.pem \
    -days 365 \
    -nodes \
    -subj "/CN=PassCard Test Certificate/O=PassCard Development/C=US"

# Создаём фиктивный WWDR
echo "📝 Creating placeholder WWDR certificate..."
cp signerCert.pem WWDR.pem

echo ""
echo "✅ Test certificates created!"
echo ""
echo "   📁 Location: $CERT_DIR"
echo "   📄 signerCert.pem"
echo "   📄 signerKey.pem"
echo "   📄 WWDR.pem"
echo ""
echo "   ⚠️  Remember: These certificates are for development only."
echo "      Passes signed with them will NOT work in Apple Wallet."
echo ""
echo "   For production, obtain real certificates from:"
echo "   https://developer.apple.com/account"
