/**
 * API маршруты для работы с пассами
 */

const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');

const PassGenerator = require('../services/PassGenerator');
const { PATHS, PASS_CONFIG } = require('../config');

// Хранилище пассов (в продакшене использовать БД)
const passStore = new Map();

/**
 * POST /api/passes/create
 * Создание нового пасса
 */
router.post('/create', async (req, res) => {
    try {
        const { ticket, deviceId, logoImageBase64, iconImageBase64, backgroundImageBase64 } = req.body;
        
        if (!ticket) {
            return res.status(400).json({ 
                success: false, 
                error: 'Ticket data is required' 
            });
        }
        
        // Генерируем уникальный серийный номер
        const serialNumber = `PASS-${Date.now()}-${uuidv4().slice(0, 8).toUpperCase()}`;
        
        // Создаем генератор пассов
        const generator = new PassGenerator();
        
        // Генерируем пасс
        const passData = await generator.generatePass({
            ticket,
            serialNumber,
            images: {
                logo: logoImageBase64,
                icon: iconImageBase64,
                background: backgroundImageBase64
            }
        });
        
        // Сохраняем в хранилище
        passStore.set(serialNumber, {
            ticket,
            deviceId,
            createdAt: new Date().toISOString(),
            passData
        });
        
        // Сохраняем файл
        const filePath = path.join(PATHS.generated, `${serialNumber}.pkpass`);
        fs.writeFileSync(filePath, passData);
        
        console.log(`✅ Pass created: ${serialNumber}`);
        
        // Отправляем пасс напрямую
        res.set({
            'Content-Type': 'application/vnd.apple.pkpass',
            'Content-Disposition': `attachment; filename="${serialNumber}.pkpass"`,
            'X-Serial-Number': serialNumber
        });
        
        res.send(passData);
        
    } catch (error) {
        console.error('Error creating pass:', error);
        res.status(500).json({ 
            success: false, 
            error: error.message 
        });
    }
});

/**
 * GET /api/passes/:serialNumber
 * Получение существующего пасса
 */
router.get('/:serialNumber', async (req, res) => {
    try {
        const { serialNumber } = req.params;
        
        // Проверяем в хранилище
        const stored = passStore.get(serialNumber);
        
        if (stored && stored.passData) {
            res.set({
                'Content-Type': 'application/vnd.apple.pkpass',
                'Content-Disposition': `attachment; filename="${serialNumber}.pkpass"`
            });
            return res.send(stored.passData);
        }
        
        // Проверяем файл на диске
        const filePath = path.join(PATHS.generated, `${serialNumber}.pkpass`);
        
        if (fs.existsSync(filePath)) {
            const passData = fs.readFileSync(filePath);
            res.set({
                'Content-Type': 'application/vnd.apple.pkpass',
                'Content-Disposition': `attachment; filename="${serialNumber}.pkpass"`
            });
            return res.send(passData);
        }
        
        res.status(404).json({ 
            success: false, 
            error: 'Pass not found' 
        });
        
    } catch (error) {
        console.error('Error getting pass:', error);
        res.status(500).json({ 
            success: false, 
            error: error.message 
        });
    }
});

/**
 * PUT /api/passes/:serialNumber
 * Обновление существующего пасса
 */
router.put('/:serialNumber', async (req, res) => {
    try {
        const { serialNumber } = req.params;
        const { ticket, logoImageBase64, iconImageBase64, backgroundImageBase64 } = req.body;
        
        if (!ticket) {
            return res.status(400).json({ 
                success: false, 
                error: 'Ticket data is required' 
            });
        }
        
        // Создаем генератор пассов
        const generator = new PassGenerator();
        
        // Генерируем обновлённый пасс с тем же серийным номером
        const passData = await generator.generatePass({
            ticket,
            serialNumber,
            images: {
                logo: logoImageBase64,
                icon: iconImageBase64,
                background: backgroundImageBase64
            }
        });
        
        // Обновляем в хранилище
        passStore.set(serialNumber, {
            ticket,
            updatedAt: new Date().toISOString(),
            passData
        });
        
        // Перезаписываем файл
        const filePath = path.join(PATHS.generated, `${serialNumber}.pkpass`);
        fs.writeFileSync(filePath, passData);
        
        console.log(`✏️ Pass updated: ${serialNumber}`);
        
        // Отправляем обновлённый пасс
        res.set({
            'Content-Type': 'application/vnd.apple.pkpass',
            'Content-Disposition': `attachment; filename="${serialNumber}.pkpass"`,
            'X-Serial-Number': serialNumber
        });
        
        res.send(passData);
        
    } catch (error) {
        console.error('Error updating pass:', error);
        res.status(500).json({ 
            success: false, 
            error: error.message 
        });
    }
});

/**
 * DELETE /api/passes/:serialNumber
 * Удаление пасса
 */
router.delete('/:serialNumber', async (req, res) => {
    try {
        const { serialNumber } = req.params;
        
        // Удаляем из хранилища
        passStore.delete(serialNumber);
        
        // Удаляем файл
        const filePath = path.join(PATHS.generated, `${serialNumber}.pkpass`);
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
        }
        
        console.log(`🗑️ Pass deleted: ${serialNumber}`);
        
        res.json({ success: true });
        
    } catch (error) {
        console.error('Error deleting pass:', error);
        res.status(500).json({ 
            success: false, 
            error: error.message 
        });
    }
});

/**
 * GET /api/passes
 * Список всех пассов
 */
router.get('/', async (req, res) => {
    try {
        const passes = Array.from(passStore.entries()).map(([serialNumber, data]) => ({
            serialNumber,
            eventName: data.ticket?.eventName,
            createdAt: data.createdAt
        }));
        
        res.json({ 
            success: true, 
            passes 
        });
        
    } catch (error) {
        console.error('Error listing passes:', error);
        res.status(500).json({ 
            success: false, 
            error: error.message 
        });
    }
});

// ============================================
// Web Service API для динамических обновлений
// ============================================

/**
 * POST /api/passes/v1/devices/:deviceId/registrations/:passTypeId/:serialNumber
 * Регистрация устройства для обновлений
 */
router.post('/v1/devices/:deviceId/registrations/:passTypeId/:serialNumber', async (req, res) => {
    const { deviceId, passTypeId, serialNumber } = req.params;
    const authToken = req.headers['authorization'];
    
    console.log(`📱 Device registration: ${deviceId} for pass ${serialNumber}`);
    
    // В продакшене: проверить authToken и сохранить в БД
    
    res.status(201).send();
});

/**
 * DELETE /api/passes/v1/devices/:deviceId/registrations/:passTypeId/:serialNumber
 * Отмена регистрации устройства
 */
router.delete('/v1/devices/:deviceId/registrations/:passTypeId/:serialNumber', async (req, res) => {
    const { deviceId, passTypeId, serialNumber } = req.params;
    
    console.log(`📱 Device unregistration: ${deviceId} for pass ${serialNumber}`);
    
    res.status(200).send();
});

/**
 * GET /api/passes/v1/devices/:deviceId/registrations/:passTypeId
 * Получение списка обновлённых пассов
 */
router.get('/v1/devices/:deviceId/registrations/:passTypeId', async (req, res) => {
    const { deviceId, passTypeId } = req.params;
    const passesUpdatedSince = req.query.passesUpdatedSince;
    
    // В продакшене: вернуть список обновлённых серийных номеров
    
    res.json({
        lastUpdated: new Date().toISOString(),
        serialNumbers: []
    });
});

/**
 * GET /api/passes/v1/passes/:passTypeId/:serialNumber
 * Получение обновлённого пасса
 */
router.get('/v1/passes/:passTypeId/:serialNumber', async (req, res) => {
    const { passTypeId, serialNumber } = req.params;
    
    // Перенаправляем на основной endpoint
    const stored = passStore.get(serialNumber);
    
    if (stored && stored.passData) {
        res.set({
            'Content-Type': 'application/vnd.apple.pkpass',
            'Last-Modified': stored.createdAt
        });
        return res.send(stored.passData);
    }
    
    res.status(304).send(); // Not Modified
});

/**
 * POST /api/passes/v1/log
 * Логирование ошибок от устройств
 */
router.post('/v1/log', async (req, res) => {
    console.log('📝 Device log:', req.body);
    res.status(200).send();
});

module.exports = router;
