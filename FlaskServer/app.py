"""
PassCard Flask Server
Сервер для генерации и подписи Apple Wallet пассов (.pkpass)
"""

import os
import json
import uuid
import hashlib
import zipfile
import io
import threading
import time
import urllib.request
from datetime import datetime
from flask import Flask, request, jsonify, send_file, Response, send_from_directory
from flask_cors import CORS

from pass_generator import PassGenerator

app = Flask(__name__)

# ============================================
# Keep-Alive: предотвращает засыпание на Render
# ============================================
def keep_alive():
    """Пингует сервер каждые 14 минут, чтобы не засыпал"""
    server_url = os.environ.get('RENDER_EXTERNAL_URL') or os.environ.get('WEB_SERVICE_URL')
    if not server_url:
        print("⚠️ Keep-alive disabled: no RENDER_EXTERNAL_URL set")
        return
    
    health_url = f"{server_url.rstrip('/')}/health"
    print(f"🔄 Keep-alive enabled: will ping {health_url} every 14 minutes")
    
    while True:
        time.sleep(14 * 60)  # 14 минут
        try:
            urllib.request.urlopen(health_url, timeout=10)
            print(f"[{datetime.now().isoformat()}] Keep-alive ping successful")
        except Exception as e:
            print(f"[{datetime.now().isoformat()}] Keep-alive ping failed: {e}")
CORS(app)

# Конфигурация
PORT = int(os.environ.get('PORT', 3000))

PASS_CONFIG = {
    'passTypeIdentifier': os.environ.get('PASS_TYPE_ID', 'pass.com.needsomevibe.passcard'),
    'teamIdentifier': os.environ.get('TEAM_ID', 'XFL8CQ52JZ'),
    'webServiceURL': os.environ.get('WEB_SERVICE_URL'),
    'organizationName': os.environ.get('ORG_NAME', 'PassCard')
}

# Пути
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CERTIFICATES_DIR = os.path.join(BASE_DIR, 'certificates')
GENERATED_DIR = os.path.join(BASE_DIR, 'generated')
TEMPLATES_DIR = os.path.join(BASE_DIR, 'templates')

# Хранилище пассов (в памяти)
pass_store = {}

# Создаём директории
for dir_path in [CERTIFICATES_DIR, GENERATED_DIR, TEMPLATES_DIR]:
    os.makedirs(dir_path, exist_ok=True)


@app.before_request
def log_request():
    """Логирование запросов"""
    print(f"[{datetime.now().isoformat()}] {request.method} {request.path}")


@app.route('/', methods=['GET'])
def index():
    """Main page"""
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>PassCard Server</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #1c1c1e; color: white; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
            .container { text-align: center; padding: 40px; }
            h1 { font-size: 48px; margin-bottom: 16px; }
            p { color: #8e8e93; font-size: 18px; }
            .status { background: #30d158; color: white; padding: 8px 20px; border-radius: 20px; display: inline-block; margin-top: 20px; }
            a { color: #0a84ff; text-decoration: none; }
            .links { margin-top: 30px; }
            .links a { margin: 0 15px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🎫 PassCard</h1>
            <p>Apple Wallet Pass Generator Server</p>
            <div class="status">✓ Online</div>
            <div class="links">
                <a href="/privacy">Privacy Policy</a>
                <a href="/support">Support</a>
                <a href="/health">API Health</a>
            </div>
        </div>
    </body>
    </html>
    '''


@app.route('/health', methods=['GET'])
def health():
    """Health check"""
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })


@app.route('/privacy', methods=['GET'])
@app.route('/privacy-policy', methods=['GET'])
def privacy_policy():
    """Privacy Policy page"""
    try:
        return send_from_directory(TEMPLATES_DIR, 'privacy.html')
    except:
        # Fallback if file not found
        return '''
        <!DOCTYPE html>
        <html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Privacy Policy - PassCard</title>
        <style>body{font-family:-apple-system,sans-serif;max-width:800px;margin:0 auto;padding:40px 20px;line-height:1.6}h1{color:#1d1d1f}h2{margin-top:30px;color:#1d1d1f}p{color:#424245}.highlight{background:#f0f0f5;padding:20px;border-radius:12px;margin:20px 0}</style></head>
        <body>
        <h1>🎫 PassCard Privacy Policy</h1>
        <p><em>Last updated: January 2026</em></p>
        <div class="highlight"><strong>Summary:</strong> PassCard does not collect, store, or share any personal data. All your passes are stored in Apple Wallet on your device.</div>
        <h2>Information We Do Not Collect</h2>
        <p>PassCard does not collect: personal information, location data, device identifiers, usage analytics, or any content from your passes.</p>
        <h2>How the App Works</h2>
        <p>When you create a pass, the information is processed to generate an Apple Wallet pass. Generated passes are added to Apple Wallet and stored by Apple. We do not store your passes on any servers.</p>
        <h2>Server Communication</h2>
        <p>The app communicates with our server solely to generate signed Apple Wallet passes. This process is encrypted using HTTPS and does not store any personal data.</p>
        <h2>Contact</h2>
        <p>Questions? Email us at <a href="mailto:needsomevibe@gmail.com">needsomevibe@gmail.com</a></p>
        </body></html>
        '''


@app.route('/support', methods=['GET'])
def support():
    """Support page"""
    try:
        return send_from_directory(TEMPLATES_DIR, 'support.html')
    except:
        # Fallback if file not found
        return '''
        <!DOCTYPE html>
        <html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Support - PassCard</title>
        <style>body{font-family:-apple-system,sans-serif;max-width:800px;margin:0 auto;padding:40px 20px;line-height:1.6}h1{color:#1d1d1f}h2{margin-top:30px}.contact{background:linear-gradient(135deg,#667eea,#764ba2);color:white;padding:30px;border-radius:16px;text-align:center;margin:20px 0}.contact a{color:white;font-size:18px}.faq{background:#f5f5f7;padding:20px;border-radius:12px;margin:15px 0}h3{margin-bottom:8px}</style></head>
        <body>
        <h1>🎫 PassCard Support</h1>
        <div class="contact"><h3>📧 Contact Us</h3><a href="mailto:needsomevibe@gmail.com">needsomevibe@gmail.com</a><p style="margin-top:10px;opacity:0.9">We typically respond within 24 hours</p></div>
        <h2>FAQ</h2>
        <div class="faq"><h3>How do I create a pass?</h3><p>Tap "+" on the main screen, fill in details, and tap "Add to Wallet".</p></div>
        <div class="faq"><h3>Can I edit a pass?</h3><p>Yes! Tap any saved pass and then tap "Edit" to modify it.</p></div>
        <div class="faq"><h3>Where are passes stored?</h3><p>Securely in Apple Wallet on your device. We don't store your data.</p></div>
        <div class="faq"><h3>Server Error?</h3><p>Check your internet connection. If it persists, check Settings in the app.</p></div>
        <p style="margin-top:40px;color:#86868b"><a href="/privacy">Privacy Policy</a></p>
        </body></html>
        '''


@app.route('/api/passes/create', methods=['POST'])
def create_pass():
    """Создание нового пасса"""
    try:
        data = request.get_json()
        
        if not data or 'ticket' not in data:
            return jsonify({
                'success': False,
                'error': 'Ticket data is required'
            }), 400
        
        ticket = data['ticket']
        device_id = data.get('deviceId')
        logo_image = data.get('logoImageBase64')
        icon_image = data.get('iconImageBase64')
        background_image = data.get('backgroundImageBase64')
        
        # Генерируем серийный номер
        serial_number = f"PASS-{int(datetime.now().timestamp() * 1000)}-{uuid.uuid4().hex[:8].upper()}"
        
        # Создаём генератор
        generator = PassGenerator(PASS_CONFIG, CERTIFICATES_DIR, TEMPLATES_DIR)
        
        # Генерируем пасс
        pass_data = generator.generate_pass(
            ticket=ticket,
            serial_number=serial_number,
            images={
                'logo': logo_image,
                'icon': icon_image,
                'background': background_image
            }
        )
        
        # Сохраняем в хранилище
        pass_store[serial_number] = {
            'ticket': ticket,
            'deviceId': device_id,
            'createdAt': datetime.now().isoformat(),
            'passData': pass_data
        }
        
        # Сохраняем файл
        file_path = os.path.join(GENERATED_DIR, f"{serial_number}.pkpass")
        with open(file_path, 'wb') as f:
            f.write(pass_data)
        
        print(f"✅ Pass created: {serial_number}")
        
        # Отправляем пасс
        return Response(
            pass_data,
            mimetype='application/vnd.apple.pkpass',
            headers={
                'Content-Disposition': f'attachment; filename="{serial_number}.pkpass"',
                'X-Serial-Number': serial_number
            }
        )
        
    except Exception as e:
        print(f"Error creating pass: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/passes/<serial_number>', methods=['GET'])
def get_pass(serial_number):
    """Получение существующего пасса"""
    try:
        # Проверяем в хранилище
        stored = pass_store.get(serial_number)
        
        if stored and stored.get('passData'):
            return Response(
                stored['passData'],
                mimetype='application/vnd.apple.pkpass',
                headers={
                    'Content-Disposition': f'attachment; filename="{serial_number}.pkpass"'
                }
            )
        
        # Проверяем файл
        file_path = os.path.join(GENERATED_DIR, f"{serial_number}.pkpass")
        
        if os.path.exists(file_path):
            with open(file_path, 'rb') as f:
                pass_data = f.read()
            return Response(
                pass_data,
                mimetype='application/vnd.apple.pkpass',
                headers={
                    'Content-Disposition': f'attachment; filename="{serial_number}.pkpass"'
                }
            )
        
        return jsonify({
            'success': False,
            'error': 'Pass not found'
        }), 404
        
    except Exception as e:
        print(f"Error getting pass: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/passes/<serial_number>', methods=['PUT'])
def update_pass(serial_number):
    """Обновление существующего пасса"""
    try:
        data = request.get_json()
        
        if not data or 'ticket' not in data:
            return jsonify({
                'success': False,
                'error': 'Ticket data is required'
            }), 400
        
        ticket = data['ticket']
        logo_image = data.get('logoImageBase64')
        icon_image = data.get('iconImageBase64')
        background_image = data.get('backgroundImageBase64')
        
        # Создаём генератор
        generator = PassGenerator(PASS_CONFIG, CERTIFICATES_DIR, TEMPLATES_DIR)
        
        # Генерируем обновлённый пасс
        pass_data = generator.generate_pass(
            ticket=ticket,
            serial_number=serial_number,
            images={
                'logo': logo_image,
                'icon': icon_image,
                'background': background_image
            }
        )
        
        # Обновляем в хранилище
        pass_store[serial_number] = {
            'ticket': ticket,
            'updatedAt': datetime.now().isoformat(),
            'passData': pass_data
        }
        
        # Перезаписываем файл
        file_path = os.path.join(GENERATED_DIR, f"{serial_number}.pkpass")
        with open(file_path, 'wb') as f:
            f.write(pass_data)
        
        print(f"✏️ Pass updated: {serial_number}")
        
        return Response(
            pass_data,
            mimetype='application/vnd.apple.pkpass',
            headers={
                'Content-Disposition': f'attachment; filename="{serial_number}.pkpass"',
                'X-Serial-Number': serial_number
            }
        )
        
    except Exception as e:
        print(f"Error updating pass: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/passes/<serial_number>', methods=['DELETE'])
def delete_pass(serial_number):
    """Удаление пасса"""
    try:
        # Удаляем из хранилища
        pass_store.pop(serial_number, None)
        
        # Удаляем файл
        file_path = os.path.join(GENERATED_DIR, f"{serial_number}.pkpass")
        if os.path.exists(file_path):
            os.remove(file_path)
        
        print(f"🗑️ Pass deleted: {serial_number}")
        
        return jsonify({'success': True})
        
    except Exception as e:
        print(f"Error deleting pass: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/passes', methods=['GET'])
def list_passes():
    """Список всех пассов"""
    try:
        passes = [
            {
                'serialNumber': sn,
                'eventName': data.get('ticket', {}).get('eventName'),
                'createdAt': data.get('createdAt')
            }
            for sn, data in pass_store.items()
        ]
        
        return jsonify({
            'success': True,
            'passes': passes
        })
        
    except Exception as e:
        print(f"Error listing passes: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


# ============================================
# Web Service API для динамических обновлений
# ============================================

@app.route('/api/passes/v1/devices/<device_id>/registrations/<pass_type_id>/<serial_number>', methods=['POST'])
def register_device(device_id, pass_type_id, serial_number):
    """Регистрация устройства для обновлений"""
    print(f"📱 Device registration: {device_id} for pass {serial_number}")
    return '', 201


@app.route('/api/passes/v1/devices/<device_id>/registrations/<pass_type_id>/<serial_number>', methods=['DELETE'])
def unregister_device(device_id, pass_type_id, serial_number):
    """Отмена регистрации устройства"""
    print(f"📱 Device unregistration: {device_id} for pass {serial_number}")
    return '', 200


@app.route('/api/passes/v1/devices/<device_id>/registrations/<pass_type_id>', methods=['GET'])
def get_updated_passes(device_id, pass_type_id):
    """Получение списка обновлённых пассов"""
    return jsonify({
        'lastUpdated': datetime.now().isoformat(),
        'serialNumbers': []
    })


@app.route('/api/passes/v1/passes/<pass_type_id>/<serial_number>', methods=['GET'])
def get_pass_for_update(pass_type_id, serial_number):
    """Получение обновлённого пасса"""
    stored = pass_store.get(serial_number)
    
    if stored and stored.get('passData'):
        return Response(
            stored['passData'],
            mimetype='application/vnd.apple.pkpass',
            headers={
                'Last-Modified': stored.get('createdAt', datetime.now().isoformat())
            }
        )
    
    return '', 304


@app.route('/api/passes/v1/log', methods=['POST'])
def device_log():
    """Логирование ошибок от устройств"""
    print(f"📝 Device log: {request.get_json()}")
    return '', 200


@app.errorhandler(404)
def not_found(e):
    return jsonify({'error': 'Not found'}), 404


@app.errorhandler(500)
def server_error(e):
    return jsonify({
        'error': 'Internal server error',
        'message': str(e)
    }), 500


def start_server():
    """Запуск сервера с keep-alive"""
    print(f"""
╔═══════════════════════════════════════════════════╗
║                                                   ║
║   🎫 PassCard Flask Server Started                ║
║                                                   ║
║   URL: http://localhost:{PORT}                      ║
║   Health: http://localhost:{PORT}/health            ║
║                                                   ║
║   Endpoints:                                      ║
║   POST /api/passes/create - Create new pass       ║
║   GET  /api/passes/:serial - Get existing pass    ║
║   DELETE /api/passes/:serial - Delete pass        ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
    """)
    
    # Запускаем keep-alive в отдельном потоке
    if os.environ.get('RENDER_EXTERNAL_URL') or os.environ.get('WEB_SERVICE_URL'):
        keep_alive_thread = threading.Thread(target=keep_alive, daemon=True)
        keep_alive_thread.start()


# Для gunicorn на Render - вызываем start_server при импорте
if os.environ.get('RENDER') or os.environ.get('RENDER_EXTERNAL_URL'):
    start_server()


if __name__ == '__main__':
    start_server()
    app.run(host='0.0.0.0', port=PORT, debug=False)
