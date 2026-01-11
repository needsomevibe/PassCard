/**
 * PassGenerator
 * 
 * Generates and signs Apple Wallet passes (.pkpass)
 * Supports all pass types: eventTicket, boardingPass, coupon, storeCard, generic
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const archiver = require('archiver');
const forge = require('node-forge');
const { PATHS, PASS_CONFIG } = require('../config');

class PassGenerator {
    constructor() {
        this.certificates = null;
    }
    
    /**
     * Load certificates
     */
    loadCertificates() {
        if (this.certificates) return this.certificates;
        
        try {
            const signerCertPem = fs.readFileSync(PATHS.signerCert, 'utf8');
            const signerKeyPem = fs.readFileSync(PATHS.signerKey, 'utf8');
            const wwdrPem = fs.readFileSync(PATHS.wwdrCert, 'utf8');
            
            const signerCert = forge.pki.certificateFromPem(signerCertPem);
            const signerKey = forge.pki.privateKeyFromPem(signerKeyPem);
            const wwdrCert = forge.pki.certificateFromPem(wwdrPem);
            
            this.certificates = { signerCert, signerKey, wwdrCert };
            return this.certificates;
            
        } catch (error) {
            console.error('Error loading certificates:', error.message);
            throw new Error(`Failed to load certificates: ${error.message}`);
        }
    }
    
    /**
     * Generate pass.json based on ticket type
     */
    generatePassJson(ticket, serialNumber) {
        const passJson = {
            formatVersion: 1,
            passTypeIdentifier: PASS_CONFIG.passTypeIdentifier,
            teamIdentifier: PASS_CONFIG.teamIdentifier,
            serialNumber: serialNumber,
            organizationName: ticket.organizationName || PASS_CONFIG.organizationName,
            description: ticket.description || ticket.eventName || 'Pass',
            
            backgroundColor: this.hexToRgb(ticket.backgroundColor || '#1C1C1E'),
            foregroundColor: this.hexToRgb(ticket.foregroundColor || '#FFFFFF'),
            labelColor: this.hexToRgb(ticket.labelColor || '#8E8E93'),
            
            barcodes: [{
                format: ticket.barcodeFormat || 'PKBarcodeFormatQR',
                message: ticket.barcodeMessage || serialNumber,
                messageEncoding: 'iso-8859-1'
            }]
        };
        
        // Logo text
        if (ticket.logoText) {
            passJson.logoText = ticket.logoText;
        }
        
        // Web Service URL for updates (optional)
        if (PASS_CONFIG.webServiceURL) {
            passJson.webServiceURL = PASS_CONFIG.webServiceURL;
            passJson.authenticationToken = crypto.randomBytes(16).toString('hex');
        }
        
        // Generate content based on pass type
        const ticketType = ticket.ticketType || 'eventTicket';
        passJson[ticketType] = this.generatePassContent(ticket, ticketType);
        
        // Add relevant date for event tickets and boarding passes
        if (ticketType === 'eventTicket' && ticket.eventDate) {
            passJson.relevantDate = ticket.isoDate || new Date(ticket.eventDate).toISOString();
        } else if (ticketType === 'boardingPass' && ticket.departureTime) {
            passJson.relevantDate = new Date(ticket.departureTime).toISOString();
        }
        
        // Add expiration for coupons
        if (ticketType === 'coupon' && ticket.expirationDate) {
            passJson.expirationDate = new Date(ticket.expirationDate).toISOString();
        }
        
        return passJson;
    }
    
    /**
     * Generate pass content based on type
     */
    generatePassContent(ticket, ticketType) {
        const content = {
            headerFields: [],
            primaryFields: [],
            secondaryFields: [],
            auxiliaryFields: [],
            backFields: []
        };
        
        switch (ticketType) {
            case 'eventTicket':
                return this.generateEventTicketContent(ticket, content);
            case 'boardingPass':
                return this.generateBoardingPassContent(ticket, content);
            case 'coupon':
                return this.generateCouponContent(ticket, content);
            case 'storeCard':
                return this.generateStoreCardContent(ticket, content);
            case 'generic':
                return this.generateGenericContent(ticket, content);
            default:
                return this.generateEventTicketContent(ticket, content);
        }
    }
    
    /**
     * Event Ticket content
     */
    generateEventTicketContent(ticket, content) {
        // Header - time
        if (ticket.eventTime) {
            content.headerFields.push({
                key: 'time',
                label: 'TIME',
                value: this.formatTime(ticket.eventTime)
            });
        }
        
        // Primary - event name
        content.primaryFields.push({
            key: 'event',
            label: 'EVENT',
            value: ticket.eventName || 'Event'
        });
        
        // Secondary
        if (ticket.venueName) {
            content.secondaryFields.push({
                key: 'venue',
                label: 'VENUE',
                value: ticket.venueName
            });
        }
        
        if (ticket.eventDate) {
            content.secondaryFields.push({
                key: 'date',
                label: 'DATE',
                value: this.formatDate(ticket.eventDate)
            });
        }
        
        // Auxiliary - seating
        const seatParts = [];
        if (ticket.seatSection) seatParts.push(`Sec ${ticket.seatSection}`);
        if (ticket.seatRow) seatParts.push(`Row ${ticket.seatRow}`);
        if (ticket.seatNumber) seatParts.push(`Seat ${ticket.seatNumber}`);
        
        if (seatParts.length > 0) {
            content.auxiliaryFields.push({
                key: 'seat',
                label: 'SEAT',
                value: seatParts.join(', ')
            });
        }
        
        if (ticket.ticketHolder) {
            content.auxiliaryFields.push({
                key: 'holder',
                label: 'ATTENDEE',
                value: ticket.ticketHolder
            });
        }
        
        // Back fields
        this.addBackFields(content, ticket);
        
        return content;
    }
    
    /**
     * Boarding Pass content
     */
    generateBoardingPassContent(ticket, content) {
        content.transitType = 'PKTransitTypeAir';
        
        // Header - gate
        if (ticket.gate) {
            content.headerFields.push({
                key: 'gate',
                label: 'GATE',
                value: ticket.gate
            });
        }
        
        // Primary - origin and destination
        content.primaryFields.push({
            key: 'origin',
            label: ticket.originCity || 'FROM',
            value: ticket.originCode || '---'
        });
        
        content.primaryFields.push({
            key: 'destination',
            label: ticket.destinationCity || 'TO',
            value: ticket.destinationCode || '---'
        });
        
        // Secondary
        if (ticket.passengerName) {
            content.secondaryFields.push({
                key: 'passenger',
                label: 'PASSENGER',
                value: ticket.passengerName
            });
        }
        
        if (ticket.departureTime) {
            content.secondaryFields.push({
                key: 'departure',
                label: 'DEPARTS',
                value: this.formatDateTime(ticket.departureTime)
            });
        }
        
        // Auxiliary
        if (ticket.flightNumber) {
            content.auxiliaryFields.push({
                key: 'flight',
                label: 'FLIGHT',
                value: ticket.flightNumber
            });
        }
        
        if (ticket.seatNumber) {
            content.auxiliaryFields.push({
                key: 'seat',
                label: 'SEAT',
                value: ticket.seatNumber
            });
        }
        
        if (ticket.seatClass) {
            content.auxiliaryFields.push({
                key: 'class',
                label: 'CLASS',
                value: ticket.seatClass
            });
        }
        
        if (ticket.boardingGroup) {
            content.auxiliaryFields.push({
                key: 'group',
                label: 'GROUP',
                value: ticket.boardingGroup
            });
        }
        
        // Back fields
        if (ticket.confirmationCode) {
            content.backFields.push({
                key: 'confirmation',
                label: 'Confirmation Code',
                value: ticket.confirmationCode
            });
        }
        
        this.addBackFields(content, ticket);
        
        return content;
    }
    
    /**
     * Coupon content
     */
    generateCouponContent(ticket, content) {
        // Primary - discount/offer
        content.primaryFields.push({
            key: 'offer',
            label: ticket.storeName || 'OFFER',
            value: ticket.discountAmount || ticket.couponTitle || 'Special Offer'
        });
        
        // Secondary
        if (ticket.couponTitle && ticket.discountAmount) {
            content.secondaryFields.push({
                key: 'title',
                label: 'PROMOTION',
                value: ticket.couponTitle
            });
        }
        
        if (ticket.promoCode) {
            content.secondaryFields.push({
                key: 'code',
                label: 'CODE',
                value: ticket.promoCode
            });
        }
        
        // Auxiliary
        if (ticket.expirationDate) {
            content.auxiliaryFields.push({
                key: 'expires',
                label: 'VALID UNTIL',
                value: this.formatDate(ticket.expirationDate)
            });
        }
        
        // Back fields
        if (ticket.termsAndConditions) {
            content.backFields.push({
                key: 'terms',
                label: 'Terms & Conditions',
                value: ticket.termsAndConditions
            });
        }
        
        this.addBackFields(content, ticket);
        
        return content;
    }
    
    /**
     * Store Card content
     */
    generateStoreCardContent(ticket, content) {
        // Primary - balance or level
        if (ticket.pointsBalance) {
            content.primaryFields.push({
                key: 'balance',
                label: 'POINTS',
                value: ticket.pointsBalance
            });
        } else {
            content.primaryFields.push({
                key: 'member',
                label: 'MEMBER',
                value: ticket.cardholderName || 'Member'
            });
        }
        
        // Secondary
        if (ticket.membershipLevel) {
            content.secondaryFields.push({
                key: 'level',
                label: 'LEVEL',
                value: ticket.membershipLevel
            });
        }
        
        if (ticket.cardholderName && ticket.pointsBalance) {
            content.secondaryFields.push({
                key: 'name',
                label: 'NAME',
                value: ticket.cardholderName
            });
        }
        
        // Auxiliary
        if (ticket.memberSince) {
            content.auxiliaryFields.push({
                key: 'since',
                label: 'MEMBER SINCE',
                value: this.formatDate(ticket.memberSince)
            });
        }
        
        this.addBackFields(content, ticket);
        
        return content;
    }
    
    /**
     * Generic pass content
     */
    generateGenericContent(ticket, content) {
        // Primary
        if (ticket.primaryValue) {
            content.primaryFields.push({
                key: 'primary',
                label: ticket.primaryLabel || '',
                value: ticket.primaryValue
            });
        }
        
        // Secondary
        if (ticket.secondaryValue) {
            content.secondaryFields.push({
                key: 'secondary',
                label: ticket.secondaryLabel || '',
                value: ticket.secondaryValue
            });
        }
        
        this.addBackFields(content, ticket);
        
        return content;
    }
    
    /**
     * Add common back fields
     */
    addBackFields(content, ticket) {
        content.backFields.push({
            key: 'organization',
            label: 'Issued by',
            value: ticket.organizationName || PASS_CONFIG.organizationName
        });
        
        if (ticket.venueAddress) {
            content.backFields.push({
                key: 'address',
                label: 'Address',
                value: ticket.venueAddress
            });
        }
        
        if (ticket.description) {
            content.backFields.push({
                key: 'description',
                label: 'Description',
                value: ticket.description
            });
        }
        
        content.backFields.push({
            key: 'generated',
            label: 'Generated by',
            value: 'PassCard App'
        });
    }
    
    /**
     * Create manifest.json with SHA1 hashes
     */
    createManifest(files) {
        const manifest = {};
        
        for (const [filename, content] of Object.entries(files)) {
            const hash = crypto.createHash('sha1').update(content).digest('hex');
            manifest[filename] = hash;
        }
        
        return manifest;
    }
    
    /**
     * Sign manifest.json
     */
    signManifest(manifestData) {
        const { signerCert, signerKey, wwdrCert } = this.loadCertificates();
        
        const p7 = forge.pkcs7.createSignedData();
        p7.content = forge.util.createBuffer(manifestData, 'utf8');
        p7.addCertificate(signerCert);
        p7.addCertificate(wwdrCert);
        
        p7.addSigner({
            key: signerKey,
            certificate: signerCert,
            digestAlgorithm: forge.pki.oids.sha256,
            authenticatedAttributes: [
                {
                    type: forge.pki.oids.contentType,
                    value: forge.pki.oids.data
                },
                {
                    type: forge.pki.oids.messageDigest
                },
                {
                    type: forge.pki.oids.signingTime,
                    value: new Date()
                }
            ]
        });
        
        p7.sign({ detached: true });
        
        const der = forge.asn1.toDer(p7.toAsn1()).getBytes();
        return Buffer.from(der, 'binary');
    }
    
    /**
     * Generate placeholder image
     */
    generatePlaceholderImage() {
        // Minimal transparent PNG
        return Buffer.from([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x01, 0x00, 0x05, 0xFE, 0xD4, 0xE7,
            0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
            0xAE, 0x42, 0x60, 0x82
        ]);
    }
    
    /**
     * Main method - generate pass
     */
    async generatePass({ ticket, serialNumber, images = {} }) {
        const files = {};
        
        // 1. Generate pass.json
        const passJson = this.generatePassJson(ticket, serialNumber);
        files['pass.json'] = Buffer.from(JSON.stringify(passJson, null, 2));
        
        // 2. Add images
        // icon.png (required)
        if (images.icon) {
            files['icon.png'] = Buffer.from(images.icon, 'base64');
            files['icon@2x.png'] = Buffer.from(images.icon, 'base64');
        } else {
            const iconPath = path.join(PATHS.templates, 'icon.png');
            if (fs.existsSync(iconPath)) {
                files['icon.png'] = fs.readFileSync(iconPath);
                files['icon@2x.png'] = fs.readFileSync(iconPath);
            } else {
                const placeholder = this.generatePlaceholderImage();
                files['icon.png'] = placeholder;
                files['icon@2x.png'] = placeholder;
            }
        }
        
        // logo.png (optional)
        if (images.logo) {
            files['logo.png'] = Buffer.from(images.logo, 'base64');
            files['logo@2x.png'] = Buffer.from(images.logo, 'base64');
        } else {
            const logoPath = path.join(PATHS.templates, 'logo.png');
            if (fs.existsSync(logoPath)) {
                files['logo.png'] = fs.readFileSync(logoPath);
                files['logo@2x.png'] = fs.readFileSync(logoPath);
            }
        }
        
        // Type-specific images
        const ticketType = ticket.ticketType || 'eventTicket';
        
        if (ticketType === 'eventTicket' && images.background) {
            files['background.png'] = Buffer.from(images.background, 'base64');
            files['background@2x.png'] = Buffer.from(images.background, 'base64');
        }
        
        if ((ticketType === 'coupon' || ticketType === 'storeCard') && images.strip) {
            files['strip.png'] = Buffer.from(images.strip, 'base64');
            files['strip@2x.png'] = Buffer.from(images.strip, 'base64');
        }
        
        if (images.thumbnail) {
            files['thumbnail.png'] = Buffer.from(images.thumbnail, 'base64');
            files['thumbnail@2x.png'] = Buffer.from(images.thumbnail, 'base64');
        }
        
        // 3. Create manifest.json
        const manifest = this.createManifest(files);
        const manifestJson = JSON.stringify(manifest);
        files['manifest.json'] = Buffer.from(manifestJson);
        
        // 4. Sign manifest
        const signature = this.signManifest(manifestJson);
        files['signature'] = signature;
        
        // 5. Create ZIP archive (.pkpass)
        return new Promise((resolve, reject) => {
            const chunks = [];
            
            const archive = archiver('zip', { zlib: { level: 9 } });
            
            archive.on('data', chunk => chunks.push(chunk));
            archive.on('end', () => resolve(Buffer.concat(chunks)));
            archive.on('error', reject);
            
            for (const [filename, content] of Object.entries(files)) {
                archive.append(content, { name: filename });
            }
            
            archive.finalize();
        });
    }
    
    // Utilities
    hexToRgb(hex) {
        const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
        if (result) {
            return `rgb(${parseInt(result[1], 16)}, ${parseInt(result[2], 16)}, ${parseInt(result[3], 16)})`;
        }
        return 'rgb(0, 0, 0)';
    }
    
    formatDate(dateString) {
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', { 
            month: 'short', 
            day: 'numeric', 
            year: 'numeric' 
        });
    }
    
    formatTime(timeString) {
        const date = new Date(timeString);
        return date.toLocaleTimeString('en-US', { 
            hour: '2-digit', 
            minute: '2-digit',
            hour12: false 
        });
    }
    
    formatDateTime(dateString) {
        const date = new Date(dateString);
        return date.toLocaleString('en-US', {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            hour12: false
        });
    }
}

module.exports = PassGenerator;
