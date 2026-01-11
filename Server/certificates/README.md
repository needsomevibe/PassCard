# 🔐 Сертификаты для подписи пассов

Эта директория должна содержать сертификаты Apple для подписи .pkpass файлов.

## Необходимые файлы

```
certificates/
├── signerCert.pem    # Сертификат Pass Type ID
├── signerKey.pem     # Приватный ключ
└── WWDR.pem          # Apple WWDR сертификат
```

## ⚠️ Важно

**НИКОГДА не коммитьте эти файлы в git!**

Файлы .pem, .p12, .cer уже добавлены в .gitignore.

## Пошаговая инструкция

### 1. Создайте Pass Type ID

1. Перейдите на [developer.apple.com](https://developer.apple.com/account)
2. **Certificates, Identifiers & Profiles** → **Identifiers**
3. Выберите **Pass Type IDs** в фильтре
4. Нажмите **+**, введите:
   - Description: `PassCard`
   - Identifier: `pass.com.yourcompany.passcard`
5. Сохраните

### 2. Создайте сертификат

1. Выберите созданный Pass Type ID
2. Нажмите **Create Certificate**
3. Создайте CSR через Keychain Access:
   - Откройте **Keychain Access**
   - **Certificate Assistant** → **Request a Certificate From a Certificate Authority**
   - Email: ваш email
   - Common Name: любое имя
   - Выберите **Saved to disk**
4. Загрузите CSR на сайт Apple
5. Скачайте сертификат (.cer)
6. Дважды кликните для установки в Keychain

### 3. Экспортируйте сертификаты

```bash
# Откройте Keychain Access
# Найдите "Pass Type ID: pass.com.yourcompany.passcard"
# Правый клик → Export
# Сохраните как .p12 с паролем

# Конвертируйте в PEM
cd Server/certificates

# Сертификат
openssl pkcs12 -in Certificates.p12 -clcerts -nokeys -out signerCert.pem -passin pass:YOUR_PASSWORD

# Приватный ключ
openssl pkcs12 -in Certificates.p12 -nocerts -out signerKey-encrypted.pem -passin pass:YOUR_PASSWORD

# Убрать пароль с ключа (для разработки)
openssl rsa -in signerKey-encrypted.pem -out signerKey.pem
rm signerKey-encrypted.pem
```

### 4. Скачайте WWDR сертификат

Apple Worldwide Developer Relations Intermediate Certificate:

```bash
# Для iOS 13+ используйте G4
curl -O https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer

# Конвертируйте в PEM
openssl x509 -inform DER -in AppleWWDRCAG4.cer -out WWDR.pem

# Удалите DER файл
rm AppleWWDRCAG4.cer
```

### 5. Проверьте файлы

```bash
# Должно показать информацию о сертификате
openssl x509 -in signerCert.pem -text -noout

# Должно показать "RSA key ok"
openssl rsa -in signerKey.pem -check

# Должно показать информацию о WWDR
openssl x509 -in WWDR.pem -text -noout
```

## Создание тестовых сертификатов (для разработки без Apple)

⚠️ **Пассы с тестовыми сертификатами НЕ будут работать в Apple Wallet!**

Для тестирования API без реальных сертификатов:

```bash
# Создаём self-signed сертификаты
openssl req -x509 -newkey rsa:2048 -keyout signerKey.pem -out signerCert.pem -days 365 -nodes -subj "/CN=PassCard Test"

# Используем тот же как WWDR (не будет работать в Wallet!)
cp signerCert.pem WWDR.pem
```

## Настройка сервера

После создания сертификатов, укажите ваш Pass Type ID и Team ID:

**Вариант 1: Переменные окружения**

```bash
export PASS_TYPE_ID="pass.com.yourcompany.passcard"
export TEAM_ID="XXXXXXXXXX"
```

**Вариант 2: config.js**

Отредактируйте `Server/src/config.js`:

```javascript
const PASS_CONFIG = {
    passTypeIdentifier: 'pass.com.yourcompany.passcard',
    teamIdentifier: 'XXXXXXXXXX',
    // ...
};
```

## Ссылки

- [Apple Pass Programming Guide](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/)
- [Certificates Authority](https://www.apple.com/certificateauthority/)
- [Wallet Developer Guide](https://developer.apple.com/wallet/)
