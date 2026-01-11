/**
 * Конфигурация сервера
 */

const path = require('path');
const fs = require('fs');

// Порт сервера
const PORT = process.env.PORT || 3000;

// Пути к файлам
const PATHS = {
    // Директория с сертификатами
    certificates: path.join(__dirname, '../certificates'),
    
    // Директория для сгенерированных пассов
    generated: path.join(__dirname, '../generated'),
    
    // Директория с шаблонами изображений
    templates: path.join(__dirname, '../templates'),
    
    // Файлы сертификатов
    signerCert: path.join(__dirname, '../certificates/signerCert.pem'),
    signerKey: path.join(__dirname, '../certificates/signerKey.pem'),
    wwdrCert: path.join(__dirname, '../certificates/WWDR.pem'),
    
    // Пароль ключа (лучше хранить в переменных окружения)
    keyPassword: process.env.PASS_KEY_PASSWORD || ''
};

// Настройки пасса (замените на свои)
const PASS_CONFIG = {
    // Ваш Pass Type ID из Apple Developer Portal
    // Формат: pass.com.yourcompany.passname
    passTypeIdentifier: process.env.PASS_TYPE_ID || 'pass.com.needsomevibe.passcard',
    
    // Ваш Team ID из Apple Developer Portal
    teamIdentifier: process.env.TEAM_ID || 'XFL8CQ52JZ',
    
    // URL для обновлений пассов (опционально)
    webServiceURL: process.env.WEB_SERVICE_URL || null,
    
    // Название организации
    organizationName: process.env.ORG_NAME || 'PassCard'
};

// Создание необходимых директорий
function ensureDirectories() {
    const dirs = [PATHS.certificates, PATHS.generated, PATHS.templates];
    
    dirs.forEach(dir => {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
            console.log(`Created directory: ${dir}`);
        }
    });
}

// Проверка наличия сертификатов
function checkCertificates() {
    const requiredFiles = [
        { path: PATHS.signerCert, name: 'Signer Certificate (signerCert.pem)' },
        { path: PATHS.signerKey, name: 'Signer Key (signerKey.pem)' },
        { path: PATHS.wwdrCert, name: 'WWDR Certificate (WWDR.pem)' }
    ];
    
    const missing = requiredFiles.filter(f => !fs.existsSync(f.path));
    
    if (missing.length > 0) {
        console.warn('\n⚠️  Missing certificates:');
        missing.forEach(f => console.warn(`   - ${f.name}`));
        console.warn('\nSee README.md for instructions on obtaining certificates.\n');
        return false;
    }
    
    return true;
}

module.exports = {
    PORT,
    PATHS,
    PASS_CONFIG,
    ensureDirectories,
    checkCertificates
};
