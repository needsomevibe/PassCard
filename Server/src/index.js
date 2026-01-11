/**
 * PassCard Server
 * 
 * Сервер для генерации и подписи Apple Wallet пассов (.pkpass)
 */

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');
const fs = require('fs');

const passRoutes = require('./routes/passes');
const { PORT, ensureDirectories } = require('./config');

const app = express();

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '10mb' }));

// Логирование запросов
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
});

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

// API Routes
app.use('/api/passes', passRoutes);

// Статические файлы (для скачивания пассов)
app.use('/passes', express.static(path.join(__dirname, '../generated')));

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).json({ 
        error: 'Internal server error',
        message: err.message 
    });
});

// Запуск сервера
ensureDirectories();

app.listen(PORT, () => {
    console.log(`
╔═══════════════════════════════════════════════════╗
║                                                   ║
║   🎫 PassCard Server Started                      ║
║                                                   ║
║   URL: http://localhost:${PORT}                      ║
║   Health: http://localhost:${PORT}/health            ║
║                                                   ║
║   Endpoints:                                      ║
║   POST /api/passes/create - Create new pass       ║
║   GET  /api/passes/:serial - Get existing pass    ║
║   DELETE /api/passes/:serial - Delete pass        ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
    `);
});
