/**
 * SAE — Bitácora Service
 * Lógica de negocio para consultar y exportar el log de auditoría.
 *
 * Cumple: RF-09 (visualizar), RF-10 (exportar PDF).
 */

'use strict';

const bitacoraRepository = require('../../repositories/bitacora/bitacora.repository');
const { derivarRolSistema } = require('../../repositories/auth/auth.repository');
const prisma = require('../../config/database');
const PDFDocument         = require('pdfkit');

// ── Colores institucionales Colegio San Diego ──────────────────
const AZUL_MARINO = '#050E77';
const AZUL_CLARO  = '#88D0F8';
const ROJO        = '#F90300';

/**
 * Traduce los registros raw (JSON) de log_auditoria a formato legible por humanos
 */
async function mapearAuditoria(registros) {
  const alumnoIds = new Set();
  const usuarioIds = new Set();

  registros.forEach(r => {
    const vAntes = typeof r.valoresAntes === 'string' ? JSON.parse(r.valoresAntes) : (r.valoresAntes || {});
    const vDespues = typeof r.valoresDespues === 'string' ? JSON.parse(r.valoresDespues) : (r.valoresDespues || {});
    
    if (vAntes.alumno_id) alumnoIds.add(Number(vAntes.alumno_id));
    if (vDespues.alumno_id) alumnoIds.add(Number(vDespues.alumno_id));
    
    if (r.tablaAfectada === 'usuario_permiso_modulo' || r.tablaAfectada === 'usuario') {
      if (vAntes.usuario_id) usuarioIds.add(Number(vAntes.usuario_id));
      if (vDespues.usuario_id) usuarioIds.add(Number(vDespues.usuario_id));
      if (r.tablaAfectada === 'usuario' && r.registroId) usuarioIds.add(Number(r.registroId));
    }
  });

  const alumnosMap = {};
  if (alumnoIds.size > 0) {
    const alumnos = await prisma.alumno.findMany({
      where: { alumnoId: { in: Array.from(alumnoIds) } },
      select: { alumnoId: true, nombreCompleto: true, matricula: true }
    });
    alumnos.forEach(a => alumnosMap[a.alumnoId] = `${a.nombreCompleto} (matrícula ${a.matricula || 'N/A'})`);
  }

  const usuariosMap = {};
  if (usuarioIds.size > 0) {
    const usuarios = await prisma.usuario.findMany({
      where: { usuarioId: { in: Array.from(usuarioIds) } },
      select: { usuarioId: true, nombreCompleto: true, nombreUsuario: true }
    });
    usuarios.forEach(u => usuariosMap[u.usuarioId] = u.nombreCompleto || u.nombreUsuario);
  }

  return registros.map(r => {
    const vAntes = typeof r.valoresAntes === 'string' ? JSON.parse(r.valoresAntes) : (r.valoresAntes || {});
    const vDespues = typeof r.valoresDespues === 'string' ? JSON.parse(r.valoresDespues) : (r.valoresDespues || {});

    const accionTraducida = r.accion === 'INSERT' ? 'Creación' :
                            r.accion === 'UPDATE' ? 'Modificación' :
                            r.accion === 'DELETE' ? 'Eliminación' : r.accion;

    const rolOperador = r.usuario?.roles ? derivarRolSistema(r.usuario.roles) : 'Sistema';
    let nombreOperador = r.usuario?.nombreCompleto || r.usuario?.nombreUsuario || 'Sistema';
    
    // Normalizar nombres de roles al español
    let rolDisplay = 'Sistema';
    if (rolOperador === 'ADMIN') rolDisplay = 'Administrador';
    else if (rolOperador === 'GESTOR') rolDisplay = 'Gestor Administrativo';
    else if (rolOperador === 'MAESTRA') rolDisplay = 'Docente';

    let entidad = r.tablaAfectada;
    let detalle = '—';

    switch(r.tablaAfectada) {
      case 'usuario':
        entidad = `Usuario: "${vDespues.nombre_usuario || vAntes.nombre_usuario}"`;
        if (r.accion === 'UPDATE') {
          if (vAntes.activo !== vDespues.activo) {
            detalle = `Estatus: ${vAntes.activo ? 'Activo' : 'Inactivo'} -> ${vDespues.activo ? 'Activo' : 'Inactivo'}`;
          } else {
            detalle = `Actualización de datos`;
          }
        }
        break;

      case 'usuario_rol':
        entidad = `Asignación de roles`;
        if (r.accion === 'INSERT') {
          detalle = `Rol asignado`;
        } else if (r.accion === 'DELETE') {
          detalle = `Rol revocado`;
        }
        break;

      case 'usuario_permiso_modulo':
        const nombreUsuarioPermiso = usuariosMap[vDespues.usuario_id || vAntes.usuario_id] || 'Usuario';
        entidad = `Permisos de "${nombreUsuarioPermiso}"`;
        if (r.accion === 'UPDATE') {
          detalle = `Módulo ${vDespues.modulo || vAntes.modulo}: ${vAntes.nivel} -> ${vDespues.nivel}`;
        } else if (r.accion === 'INSERT') {
          detalle = `Módulo ${vDespues.modulo}: asignado como ${vDespues.nivel}`;
        } else if (r.accion === 'DELETE') {
          detalle = `Permisos revocados del módulo ${vAntes.modulo}`;
        }
        break;

      case 'pago':
        const alumnoPago = alumnosMap[vDespues.alumno_id || vAntes.alumno_id] || 'Alumno';
        entidad = `Pago / Expediente "${alumnoPago}"`;
        if (r.accion === 'INSERT') {
          detalle = `Monto total: $${Number(vDespues.monto_total).toFixed(2)}`;
        } else if (r.accion === 'UPDATE') {
          detalle = `Actualización de pago. Monto: $${Number(vAntes.monto_total).toFixed(2)} -> $${Number(vDespues.monto_total).toFixed(2)}`;
        }
        break;
        
      case 'calendario_pago':
        entidad = `Colegiatura / Concepto: ${vDespues.concepto || vAntes.concepto}`;
        if (r.accion === 'UPDATE') {
          if (vAntes.monto_pagado !== vDespues.monto_pagado) {
             detalle = `Monto pagado: $${Number(vAntes.monto_pagado).toFixed(2)} -> $${Number(vDespues.monto_pagado).toFixed(2)}`;
          } else if (vAntes.estado_cobro !== vDespues.estado_cobro) {
             detalle = `Estado: ${vAntes.estado_cobro} -> ${vDespues.estado_cobro}`;
          } else {
             detalle = 'Modificación de concepto';
          }
        }
        break;

      case 'recargo':
        entidad = `Recargo automático (RF-33)`;
        if (r.accion === 'INSERT' || r.accion === 'UPDATE') {
          detalle = `Monto actual: $${Number(vDespues.monto_actual).toFixed(2)}`;
        }
        break;

      case 'asignacion_beca':
        const alumnoBeca = alumnosMap[vDespues.alumno_id || vAntes.alumno_id] || 'Alumno';
        entidad = `Beca / Expediente "${alumnoBeca}"`;
        if (r.accion === 'INSERT') {
          detalle = `Beca asignada: ${Number(vDespues.porcentaje_descuento)}%`;
        } else if (r.accion === 'UPDATE' && !vDespues.activa && vAntes.activa) {
          detalle = `Beca retirada — motivo "${vDespues.motivo_retiro || 'mora reincidente (RF-28)'}"`;
        } else if (r.accion === 'UPDATE') {
          detalle = `Modificación de beca: ${Number(vAntes.porcentaje_descuento)}% -> ${Number(vDespues.porcentaje_descuento)}%`;
        } else if (r.accion === 'DELETE') {
           detalle = `Beca retirada`;
        }
        break;

      case 'alumno':
        entidad = `Estatus alumno / Expediente "${vDespues.nombre_completo || vAntes.nombre_completo}"`;
        if (r.accion === 'UPDATE') {
           if (vAntes.estatus !== vDespues.estatus) {
             detalle = `Estatus: ${vAntes.estatus} -> ${vDespues.estatus}`;
           } else {
             detalle = `Modificación de datos del alumno`;
           }
        }
        break;

      case 'beca':
        entidad = `Catálogo de Becas: "${vDespues.nombre_beca || vAntes.nombre_beca}"`;
        if (r.accion === 'INSERT') {
          detalle = `Nueva beca registrada: ${vDespues.porcentaje}% (${vDespues.criterio})`;
        } else if (r.accion === 'UPDATE') {
          detalle = `Actualización de beca`;
        }
        break;

      case 'ciclo_escolar':
        entidad = `Ciclo Escolar: "${vDespues.nombre || vAntes.nombre}"`;
        if (r.accion === 'INSERT') {
          detalle = `Ciclo creado`;
        } else if (r.accion === 'UPDATE') {
          if (vAntes.activo !== undefined && vAntes.activo !== vDespues.activo) {
            detalle = `Estatus cambiado a: ${vDespues.activo ? 'Activo' : 'Inactivo'}`;
          } else {
            detalle = `Actualización de ciclo escolar`;
          }
        }
        break;

      case 'tarifa':
        entidad = `Tarifa: ${vDespues.concepto || vAntes.concepto}`;
        if (r.accion === 'INSERT') {
          detalle = `Tarifa registrada: $${Number(vDespues.monto).toFixed(2)}`;
        } else if (r.accion === 'UPDATE') {
          detalle = `Tarifa actualizada: $${Number(vAntes.monto).toFixed(2)} -> $${Number(vDespues.monto).toFixed(2)}`;
        }
        break;

      default:
        entidad = r.tablaAfectada;
        detalle = r.accion === 'DELETE' ? 'Registro eliminado' : '—';
        break;
    }

    return {
      logId: r.logId.toString(),
      fechaHora: r.fechaHora,
      usuario: nombreOperador,
      rol: rolDisplay,
      tipoAccion: accionTraducida,
      entidad: entidad,
      detalle: detalle
    };
  });
}

/**
 * Lista registros de la bitácora con filtros y paginación.
 */
async function listar({ fechaInicio, fechaFin, usuarioId, accion, rol, pagina, limite }) {
  const result = await bitacoraRepository.findAll({ fechaInicio, fechaFin, usuarioId, accion, rol, pagina, limite });
  result.datos = await mapearAuditoria(result.datos);
  return result;
}

/**
 * Genera un PDF de la bitácora con los filtros indicados.
 * Retorna un Buffer con el contenido del PDF.
 *
 * @param {{ fechaInicio?, fechaFin?, usuarioId? }} filtros
 * @returns {Promise<Buffer>}
 */
async function exportarPDF(filtros) {
  // Obtener TODOS los registros para el export (sin paginación)
  const result = await bitacoraRepository.findAll({ ...filtros, limite: 10000, pagina: 1 });
  const datosTraduccion = await mapearAuditoria(result.datos);

  return new Promise((resolve, reject) => {
    const buffers = [];
    // Cambiar a layout horizontal para que quepan todas las columnas
    const doc = new PDFDocument({ margin: 40, size: 'A4', layout: 'landscape', bufferPages: true });

    doc.on('data', (chunk) => buffers.push(chunk));
    doc.on('end',  () => resolve(Buffer.concat(buffers)));
    doc.on('error', reject);

    // ── Encabezado ───────────────────────────────────────────
    doc
      .fillColor(AZUL_MARINO)
      .fontSize(16)
      .font('Helvetica-Bold')
      .text('COLEGIO SAN DIEGO', { align: 'center' });

    doc
      .fillColor(ROJO)
      .fontSize(12)
      .font('Helvetica-Bold')
      .text('Bitácora de Auditoría del Sistema', { align: 'center' });

    // Filtros aplicados
    const rangoFechas = filtros.fechaInicio || filtros.fechaFin
      ? `Período: ${filtros.fechaInicio || '—'} al ${filtros.fechaFin || '—'}`
      : 'Período: todos los registros';

    doc
      .moveDown(0.5)
      .fillColor('#444444')
      .fontSize(9)
      .font('Helvetica')
      .text(rangoFechas, { align: 'center' })
      .text(`Generado: ${new Date().toLocaleString('es-MX', { timeZone: 'America/Mexico_City' })}`, { align: 'center' })
      .text(`Total de registros: ${datosTraduccion.length}`, { align: 'center' });

    doc.moveDown(1);

    // ── Línea separadora ──────────────────────────────────────
    doc
      .moveTo(40, doc.y)
      .lineTo(800, doc.y)
      .strokeColor(AZUL_MARINO)
      .lineWidth(1.5)
      .stroke();

    doc.moveDown(0.5);

    // ── Cabecera de tabla ─────────────────────────────────────
    const colX    = { fecha: 40, usuario: 140, rol: 250, accion: 330, entidad: 400, detalle: 580 };
    const rowH    = 16;
    let headerY = doc.y;

    function drawHeader() {
      doc
        .fillColor(AZUL_MARINO)
        .rect(40, headerY - 2, 760, rowH + 4)
        .fill();

      doc
        .fillColor('white')
        .fontSize(8)
        .font('Helvetica-Bold')
        .text('Fecha / Hora',   colX.fecha,    headerY, { width: 90, lineBreak: false })
        .text('Usuario',        colX.usuario,  headerY, { width: 100, lineBreak: false })
        .text('Rol',            colX.rol,      headerY, { width: 70,  lineBreak: false })
        .text('Acción',         colX.accion,   headerY, { width: 60,  lineBreak: false })
        .text('Módulo / Entidad', colX.entidad,  headerY, { width: 170, lineBreak: false })
        .text('Detalle',        colX.detalle,  headerY, { width: 220, lineBreak: false });
      
      doc.y = headerY + rowH + 8;
    }

    drawHeader();

    // ── Filas ─────────────────────────────────────────────────
    doc.font('Helvetica').fontSize(8);
    let alternarColor = false;

    datosTraduccion.forEach((item) => {
      // Calcular altura máxima para la fila actual
      const heightEntidad = doc.heightOfString(item.entidad, { width: 170 });
      const heightDetalle = doc.heightOfString(item.detalle, { width: 220 });
      const itemRowH = Math.max(14, heightEntidad, heightDetalle) + 6;

      if (doc.y + itemRowH > doc.page.height - 50) {
        doc.addPage();
        headerY = 40;
        drawHeader();
        doc.font('Helvetica').fontSize(8);
      }

      const y = doc.y;

      // Fondo cebra
      if (alternarColor) {
        doc.fillColor('#F9FAFB').rect(40, y - 2, 760, itemRowH).fill();
      }
      alternarColor = !alternarColor;

      const fechaLocale = new Date(item.fechaHora).toLocaleString('es-MX', { timeZone: 'America/Mexico_City' });

      doc.fillColor('#333333');
      doc.text(fechaLocale,   colX.fecha,   y, { width: 90 });
      doc.text(item.usuario,  colX.usuario, y, { width: 100 });
      doc.text(item.rol,      colX.rol,     y, { width: 70 });
      
      // Color según la acción
      if (item.tipoAccion === 'Creación') doc.fillColor('#059669');
      else if (item.tipoAccion === 'Eliminación') doc.fillColor('#DC2626');
      else doc.fillColor('#2563EB');
      
      doc.text(item.tipoAccion, colX.accion, y, { width: 60 });

      doc.fillColor('#444444');
      doc.text(item.entidad,  colX.entidad, y, { width: 170 });
      doc.text(item.detalle,  colX.detalle, y, { width: 220 });

      doc.y = y + itemRowH;
    });

    // ── Paginación ────────────────────────────────────────────
    const pages = doc.bufferedPageRange();
    for (let i = 0; i < pages.count; i++) {
      doc.switchToPage(i);
      doc.font('Helvetica').fontSize(7).fillColor('#999999');
      doc.text(
        `Página ${i + 1} de ${pages.count}`,
        40, doc.page.height - 30,
        { align: 'right', width: 760 }
      );
    }

    doc.end();
  });
}

module.exports = { listar, exportarPDF };
