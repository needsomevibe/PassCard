"""
PassGenerator
Generates and signs Apple Wallet passes (.pkpass)
"""

import os
import json
import hashlib
import secrets
import zipfile
import io
import base64
from datetime import datetime

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.serialization import pkcs7
from cryptography.hazmat.backends import default_backend


class PassGenerator:
    def __init__(self, pass_config, certificates_dir, templates_dir):
        self.pass_config = pass_config
        self.certificates_dir = certificates_dir
        self.templates_dir = templates_dir
        self.certificates = None
    
    def load_certificates(self):
        """Load certificates"""
        if self.certificates:
            return self.certificates
        
        try:
            signer_cert_path = os.path.join(self.certificates_dir, 'signerCert.pem')
            signer_key_path = os.path.join(self.certificates_dir, 'signerKey.pem')
            wwdr_cert_path = os.path.join(self.certificates_dir, 'WWDR.pem')
            
            with open(signer_cert_path, 'rb') as f:
                signer_cert = x509.load_pem_x509_certificate(f.read(), default_backend())
            
            with open(signer_key_path, 'rb') as f:
                key_password = os.environ.get('PASS_KEY_PASSWORD', '').encode() or None
                signer_key = serialization.load_pem_private_key(
                    f.read(),
                    password=key_password,
                    backend=default_backend()
                )
            
            with open(wwdr_cert_path, 'rb') as f:
                wwdr_cert = x509.load_pem_x509_certificate(f.read(), default_backend())
            
            self.certificates = {
                'signer_cert': signer_cert,
                'signer_key': signer_key,
                'wwdr_cert': wwdr_cert
            }
            return self.certificates
            
        except Exception as e:
            raise Exception(f"Failed to load certificates: {e}")
    
    def generate_pass_json(self, ticket, serial_number):
        """Generate pass.json based on ticket type"""
        pass_json = {
            'formatVersion': 1,
            'passTypeIdentifier': self.pass_config['passTypeIdentifier'],
            'teamIdentifier': self.pass_config['teamIdentifier'],
            'serialNumber': serial_number,
            'organizationName': ticket.get('organizationName', self.pass_config['organizationName']),
            'description': ticket.get('description') or ticket.get('eventName') or 'Pass',
            
            'backgroundColor': self.hex_to_rgb(ticket.get('backgroundColor', '#1C1C1E')),
            'foregroundColor': self.hex_to_rgb(ticket.get('foregroundColor', '#FFFFFF')),
            'labelColor': self.hex_to_rgb(ticket.get('labelColor', '#8E8E93')),
            
            'barcodes': [{
                'format': ticket.get('barcodeFormat', 'PKBarcodeFormatQR'),
                'message': ticket.get('barcodeMessage', serial_number),
                'messageEncoding': 'iso-8859-1'
            }]
        }
        
        # Logo text
        if ticket.get('logoText'):
            pass_json['logoText'] = ticket['logoText']
        
        # Web Service URL
        if self.pass_config.get('webServiceURL'):
            pass_json['webServiceURL'] = self.pass_config['webServiceURL']
            pass_json['authenticationToken'] = secrets.token_hex(16)
        
        # Generate content based on pass type
        ticket_type = ticket.get('ticketType', 'eventTicket')
        pass_json[ticket_type] = self.generate_pass_content(ticket, ticket_type)
        
        # Relevant date
        if ticket_type == 'eventTicket' and ticket.get('eventDate'):
            pass_json['relevantDate'] = ticket.get('isoDate') or self.to_iso_date(ticket['eventDate'])
        elif ticket_type == 'boardingPass' and ticket.get('departureTime'):
            pass_json['relevantDate'] = self.to_iso_date(ticket['departureTime'])
        
        # Expiration for coupons
        if ticket_type == 'coupon' and ticket.get('expirationDate'):
            pass_json['expirationDate'] = self.to_iso_date(ticket['expirationDate'])
        
        return pass_json
    
    def generate_pass_content(self, ticket, ticket_type):
        """Generate pass content based on type"""
        content = {
            'headerFields': [],
            'primaryFields': [],
            'secondaryFields': [],
            'auxiliaryFields': [],
            'backFields': []
        }
        
        generators = {
            'eventTicket': self.generate_event_ticket_content,
            'boardingPass': self.generate_boarding_pass_content,
            'coupon': self.generate_coupon_content,
            'storeCard': self.generate_store_card_content,
            'generic': self.generate_generic_content
        }
        
        generator = generators.get(ticket_type, self.generate_event_ticket_content)
        return generator(ticket, content)
    
    def generate_event_ticket_content(self, ticket, content):
        """Event Ticket content"""
        # Header - time
        if ticket.get('eventTime'):
            content['headerFields'].append({
                'key': 'time',
                'label': 'TIME',
                'value': self.format_time(ticket['eventTime'])
            })
        
        # Primary - event name
        content['primaryFields'].append({
            'key': 'event',
            'label': 'EVENT',
            'value': ticket.get('eventName', 'Event')
        })
        
        # Secondary
        if ticket.get('venueName'):
            content['secondaryFields'].append({
                'key': 'venue',
                'label': 'VENUE',
                'value': ticket['venueName']
            })
        
        if ticket.get('eventDate'):
            content['secondaryFields'].append({
                'key': 'date',
                'label': 'DATE',
                'value': self.format_date(ticket['eventDate'])
            })
        
        # Auxiliary - seating
        seat_parts = []
        if ticket.get('seatSection'):
            seat_parts.append(f"Sec {ticket['seatSection']}")
        if ticket.get('seatRow'):
            seat_parts.append(f"Row {ticket['seatRow']}")
        if ticket.get('seatNumber'):
            seat_parts.append(f"Seat {ticket['seatNumber']}")
        
        if seat_parts:
            content['auxiliaryFields'].append({
                'key': 'seat',
                'label': 'SEAT',
                'value': ', '.join(seat_parts)
            })
        
        if ticket.get('ticketHolder'):
            content['auxiliaryFields'].append({
                'key': 'holder',
                'label': 'ATTENDEE',
                'value': ticket['ticketHolder']
            })
        
        self.add_back_fields(content, ticket)
        return content
    
    def generate_boarding_pass_content(self, ticket, content):
        """Boarding Pass content"""
        content['transitType'] = 'PKTransitTypeAir'
        
        # Header - gate
        if ticket.get('gate'):
            content['headerFields'].append({
                'key': 'gate',
                'label': 'GATE',
                'value': ticket['gate']
            })
        
        # Primary - origin and destination
        content['primaryFields'].append({
            'key': 'origin',
            'label': ticket.get('originCity', 'FROM'),
            'value': ticket.get('originCode', '---')
        })
        
        content['primaryFields'].append({
            'key': 'destination',
            'label': ticket.get('destinationCity', 'TO'),
            'value': ticket.get('destinationCode', '---')
        })
        
        # Secondary
        if ticket.get('passengerName'):
            content['secondaryFields'].append({
                'key': 'passenger',
                'label': 'PASSENGER',
                'value': ticket['passengerName']
            })
        
        if ticket.get('departureTime'):
            content['secondaryFields'].append({
                'key': 'departure',
                'label': 'DEPARTS',
                'value': self.format_datetime(ticket['departureTime'])
            })
        
        # Auxiliary
        if ticket.get('flightNumber'):
            content['auxiliaryFields'].append({
                'key': 'flight',
                'label': 'FLIGHT',
                'value': ticket['flightNumber']
            })
        
        if ticket.get('seatNumber'):
            content['auxiliaryFields'].append({
                'key': 'seat',
                'label': 'SEAT',
                'value': ticket['seatNumber']
            })
        
        if ticket.get('seatClass'):
            content['auxiliaryFields'].append({
                'key': 'class',
                'label': 'CLASS',
                'value': ticket['seatClass']
            })
        
        if ticket.get('boardingGroup'):
            content['auxiliaryFields'].append({
                'key': 'group',
                'label': 'GROUP',
                'value': ticket['boardingGroup']
            })
        
        # Back fields
        if ticket.get('confirmationCode'):
            content['backFields'].append({
                'key': 'confirmation',
                'label': 'Confirmation Code',
                'value': ticket['confirmationCode']
            })
        
        self.add_back_fields(content, ticket)
        return content
    
    def generate_coupon_content(self, ticket, content):
        """Coupon content"""
        # Primary - discount/offer
        content['primaryFields'].append({
            'key': 'offer',
            'label': ticket.get('storeName', 'OFFER'),
            'value': ticket.get('discountAmount') or ticket.get('couponTitle') or 'Special Offer'
        })
        
        # Secondary
        if ticket.get('couponTitle') and ticket.get('discountAmount'):
            content['secondaryFields'].append({
                'key': 'title',
                'label': 'PROMOTION',
                'value': ticket['couponTitle']
            })
        
        if ticket.get('promoCode'):
            content['secondaryFields'].append({
                'key': 'code',
                'label': 'CODE',
                'value': ticket['promoCode']
            })
        
        # Auxiliary
        if ticket.get('expirationDate'):
            content['auxiliaryFields'].append({
                'key': 'expires',
                'label': 'VALID UNTIL',
                'value': self.format_date(ticket['expirationDate'])
            })
        
        # Back fields
        if ticket.get('termsAndConditions'):
            content['backFields'].append({
                'key': 'terms',
                'label': 'Terms & Conditions',
                'value': ticket['termsAndConditions']
            })
        
        self.add_back_fields(content, ticket)
        return content
    
    def generate_store_card_content(self, ticket, content):
        """Store Card content"""
        # Primary - balance or level
        if ticket.get('pointsBalance'):
            content['primaryFields'].append({
                'key': 'balance',
                'label': 'POINTS',
                'value': ticket['pointsBalance']
            })
        else:
            content['primaryFields'].append({
                'key': 'member',
                'label': 'MEMBER',
                'value': ticket.get('cardholderName', 'Member')
            })
        
        # Secondary
        if ticket.get('membershipLevel'):
            content['secondaryFields'].append({
                'key': 'level',
                'label': 'LEVEL',
                'value': ticket['membershipLevel']
            })
        
        if ticket.get('cardholderName') and ticket.get('pointsBalance'):
            content['secondaryFields'].append({
                'key': 'name',
                'label': 'NAME',
                'value': ticket['cardholderName']
            })
        
        # Auxiliary
        if ticket.get('memberSince'):
            content['auxiliaryFields'].append({
                'key': 'since',
                'label': 'MEMBER SINCE',
                'value': self.format_date(ticket['memberSince'])
            })
        
        self.add_back_fields(content, ticket)
        return content
    
    def generate_generic_content(self, ticket, content):
        """Generic pass content"""
        # Primary
        if ticket.get('primaryValue'):
            content['primaryFields'].append({
                'key': 'primary',
                'label': ticket.get('primaryLabel', ''),
                'value': ticket['primaryValue']
            })
        
        # Secondary
        if ticket.get('secondaryValue'):
            content['secondaryFields'].append({
                'key': 'secondary',
                'label': ticket.get('secondaryLabel', ''),
                'value': ticket['secondaryValue']
            })
        
        self.add_back_fields(content, ticket)
        return content
    
    def add_back_fields(self, content, ticket):
        """Add common back fields"""
        content['backFields'].append({
            'key': 'organization',
            'label': 'Issued by',
            'value': ticket.get('organizationName', self.pass_config['organizationName'])
        })
        
        if ticket.get('venueAddress'):
            content['backFields'].append({
                'key': 'address',
                'label': 'Address',
                'value': ticket['venueAddress']
            })
        
        if ticket.get('description'):
            content['backFields'].append({
                'key': 'description',
                'label': 'Description',
                'value': ticket['description']
            })
        
        content['backFields'].append({
            'key': 'generated',
            'label': 'Generated by',
            'value': 'PassCard App'
        })
    
    def create_manifest(self, files):
        """Create manifest.json with SHA1 hashes"""
        manifest = {}
        for filename, content in files.items():
            hash_obj = hashlib.sha1(content)
            manifest[filename] = hash_obj.hexdigest()
        return manifest
    
    def sign_manifest(self, manifest_data):
        """Sign manifest.json using PKCS#7"""
        certs = self.load_certificates()
        
        # Build the PKCS#7 signed data
        signed_data = pkcs7.PKCS7SignatureBuilder().set_data(
            manifest_data
        ).add_signer(
            certs['signer_cert'],
            certs['signer_key'],
            hashes.SHA256()
        ).add_certificate(
            certs['wwdr_cert']
        ).sign(
            serialization.Encoding.DER,
            options=[pkcs7.PKCS7Options.DetachedSignature]
        )
        
        return signed_data
    
    def generate_placeholder_image(self):
        """Generate minimal transparent PNG"""
        return bytes([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x01, 0x00, 0x05, 0xFE, 0xD4, 0xE7,
            0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
            0xAE, 0x42, 0x60, 0x82
        ])
    
    def generate_pass(self, ticket, serial_number, images=None):
        """Main method - generate pass"""
        images = images or {}
        files = {}
        
        # 1. Generate pass.json
        pass_json = self.generate_pass_json(ticket, serial_number)
        files['pass.json'] = json.dumps(pass_json, indent=2).encode('utf-8')
        
        # 2. Add images
        # icon.png (required)
        if images.get('icon'):
            icon_data = base64.b64decode(images['icon'])
            files['icon.png'] = icon_data
            files['icon@2x.png'] = icon_data
        else:
            icon_path = os.path.join(self.templates_dir, 'icon.png')
            if os.path.exists(icon_path):
                with open(icon_path, 'rb') as f:
                    icon_data = f.read()
                files['icon.png'] = icon_data
                files['icon@2x.png'] = icon_data
            else:
                placeholder = self.generate_placeholder_image()
                files['icon.png'] = placeholder
                files['icon@2x.png'] = placeholder
        
        # logo.png (optional)
        if images.get('logo'):
            logo_data = base64.b64decode(images['logo'])
            files['logo.png'] = logo_data
            files['logo@2x.png'] = logo_data
        else:
            logo_path = os.path.join(self.templates_dir, 'logo.png')
            if os.path.exists(logo_path):
                with open(logo_path, 'rb') as f:
                    logo_data = f.read()
                files['logo.png'] = logo_data
                files['logo@2x.png'] = logo_data
        
        # Type-specific images
        ticket_type = ticket.get('ticketType', 'eventTicket')
        
        if ticket_type == 'eventTicket' and images.get('background'):
            bg_data = base64.b64decode(images['background'])
            files['background.png'] = bg_data
            files['background@2x.png'] = bg_data
        
        if ticket_type in ('coupon', 'storeCard') and images.get('strip'):
            strip_data = base64.b64decode(images['strip'])
            files['strip.png'] = strip_data
            files['strip@2x.png'] = strip_data
        
        if images.get('thumbnail'):
            thumb_data = base64.b64decode(images['thumbnail'])
            files['thumbnail.png'] = thumb_data
            files['thumbnail@2x.png'] = thumb_data
        
        # 3. Create manifest.json
        manifest = self.create_manifest(files)
        manifest_json = json.dumps(manifest).encode('utf-8')
        files['manifest.json'] = manifest_json
        
        # 4. Sign manifest
        signature = self.sign_manifest(manifest_json)
        files['signature'] = signature
        
        # 5. Create ZIP archive (.pkpass)
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
            for filename, content in files.items():
                zf.writestr(filename, content)
        
        return buffer.getvalue()
    
    # Utilities
    def hex_to_rgb(self, hex_color):
        """Convert hex to rgb() string"""
        hex_color = hex_color.lstrip('#')
        if len(hex_color) == 6:
            r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
            return f"rgb({r}, {g}, {b})"
        return "rgb(0, 0, 0)"
    
    def format_date(self, date_string):
        """Format date string"""
        try:
            dt = datetime.fromisoformat(date_string.replace('Z', '+00:00'))
            return dt.strftime('%b %d, %Y')
        except:
            return date_string
    
    def format_time(self, time_string):
        """Format time string"""
        try:
            dt = datetime.fromisoformat(time_string.replace('Z', '+00:00'))
            return dt.strftime('%H:%M')
        except:
            return time_string
    
    def format_datetime(self, date_string):
        """Format datetime string"""
        try:
            dt = datetime.fromisoformat(date_string.replace('Z', '+00:00'))
            return dt.strftime('%b %d, %H:%M')
        except:
            return date_string
    
    def to_iso_date(self, date_string):
        """Convert to ISO date string"""
        try:
            dt = datetime.fromisoformat(date_string.replace('Z', '+00:00'))
            return dt.isoformat()
        except:
            return datetime.now().isoformat()
