'use strict';

const nodemailer = require('nodemailer');

let transporter = null;

/**
 * Inicializa el transporter de Nodemailer.
 * Si no hay credenciales SMTP en el .env, usa Ethereal Email (cuenta de prueba).
 */
async function initTransporter() {
  if (transporter) return transporter;

  if (process.env.SMTP_USER && process.env.SMTP_PASS) {
    // Producción o SMTP Real
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: process.env.SMTP_PORT || 587,
      secure: process.env.SMTP_SECURE === 'true',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
    console.log('✅ MailerService: Transporter SMTP real configurado.');
  } else {
    // Cuenta de prueba automática (Ethereal)
    console.log('⚠️ MailerService: No hay SMTP_USER. Creando cuenta de prueba en Ethereal...');
    const testAccount = await nodemailer.createTestAccount();
    transporter = nodemailer.createTransport({
      host: 'smtp.ethereal.email',
      port: 587,
      secure: false,
      auth: {
        user: testAccount.user,
        pass: testAccount.pass,
      },
    });
    console.log('✅ MailerService: Cuenta de prueba Ethereal configurada.');
  }

  return transporter;
}

/**
 * Envía un correo con una plantilla HTML genérica del Colegio San Diego.
 * @param {string} to - Destinatario
 * @param {string} subject - Asunto
 * @param {string} bodyHtml - Cuerpo en HTML
 */
async function enviarCorreo(to, subject, bodyHtml) {
  const t = await initTransporter();

  // Plantilla HTML Base
  const htmlTemplate = `
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f3f4f6; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
        .header { background-color: #1e293b; padding: 24px; text-align: center; color: white; }
        .header h1 { margin: 0; font-size: 24px; letter-spacing: 1px; }
        .content { padding: 32px 24px; color: #334155; line-height: 1.6; }
        .footer { background-color: #f8fafc; padding: 16px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; }
        .accent { color: #059669; font-weight: bold; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>COLEGIO SAN DIEGO</h1>
        </div>
        <div class="content">
          ${bodyHtml}
        </div>
        <div class="footer">
          Este es un mensaje automático del Sistema Administrativo Escolar (SAE).<br>
          Colegio San Diego &copy; ${new Date().getFullYear()}
        </div>
      </div>
    </body>
    </html>
  `;

  const mailOptions = {
    from: '"Colegio San Diego" <notificaciones@colegiosandiego.edu.mx>',
    to,
    subject,
    html: htmlTemplate,
  };

  try {
    const info = await t.sendMail(mailOptions);
    console.log(`✉️ Correo enviado a ${to}. Asunto: "${subject}"`);
    
    // Si se usó Ethereal, mostrar el enlace de preview
    if (!process.env.SMTP_USER) {
      console.log(`🔗 Preview URL: ${nodemailer.getTestMessageUrl(info)}`);
    }
    
    return { exito: true, messageId: info.messageId, previewUrl: nodemailer.getTestMessageUrl(info) };
  } catch (error) {
    console.error('❌ Error enviando correo:', error);
    return { exito: false, error: error.message };
  }
}

module.exports = {
  enviarCorreo,
};
