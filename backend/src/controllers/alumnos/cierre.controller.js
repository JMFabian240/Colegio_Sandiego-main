'use strict';

const prisma = require('../../config/database');
const { withAudit } = require('../../utils/audit.utils');
const calendarioPagoService = require('../../services/pagos/calendarioPago.service');

/**
 * Ejecutar cierre de ciclo escolar (RF-21)
 * Promueve a regulares, egresa a grado final, retiene morosos.
 */
async function cerrarCiclo(req, res) {
  try {
    const usuarioId = req.user.usuarioId;
    const ip = req.ip;

    const resultado = await withAudit(usuarioId, ip, async (tx) => {
      // 1. Obtener el ciclo activo
      const cicloActivo = await tx.cicloEscolar.findFirst({
        where: { activo: true }
      });
      
      if (!cicloActivo) {
        throw new Error('No hay ciclo escolar activo configurado.');
      }

      // 2. Obtener todos los alumnos inscritos en este ciclo
      const alumnosInscritos = await tx.inscripcionCiclo.findMany({
        where: { 
          cicloId: cicloActivo.cicloId,
          eliminadoEn: null,
          alumno: { eliminadoEn: null, estado: 'Activo' }
        },
        include: {
          alumno: {
            include: {
              nivel: true,
              calendariosPago: {
                where: { cicloId: cicloActivo.cicloId },
                include: { colegiaturas: true }
              }
            }
          },
          grupo: {
            include: { nivel: true }
          }
        }
      });

      let promovidos = 0;
      let egresados = 0;
      let retenidos = 0;

      for (const inscripcion of alumnosInscritos) {
        const alumno = inscripcion.alumno;
        if (!alumno || !alumno.nivel) continue;

        // Validar adeudos
        let tieneAdeudo = false;
        if (alumno.calendariosPago && alumno.calendariosPago.length > 0) {
          const calendario = alumno.calendariosPago[0];
          const colegiaturasVencidas = calendario.colegiaturas.filter(c => 
            c.estado !== 'Pagado' && new Date(c.fechaVencimiento) < new Date()
          );
          if (colegiaturasVencidas.length > 0) {
            tieneAdeudo = true;
          }
        }

        if (tieneAdeudo) {
          // RF-21: Retener alumno con adeudos (Transición Pendiente)
          await tx.inscripcionCiclo.update({
            where: { inscripcionId: inscripcion.inscripcionId },
            data: { estadoEnCiclo: 'transicion_pendiente' }
          });
          retenidos++;
        } else {
          // RF-21: Promoción regular
          const esGradoFinal = (alumno.nivel.codigo === 'PREESCOLAR' && inscripcion.grupo.grado === 3) ||
                               (alumno.nivel.codigo === 'PRIMARIA' && inscripcion.grupo.grado === 6) ||
                               (alumno.nivel.codigo === 'SECUNDARIA' && inscripcion.grupo.grado === 3) ||
                               (alumno.nivel.codigo === 'BACHILLERATO' && inscripcion.grupo.grado === 6);
          
          if (esGradoFinal) {
            // Egresa
            await tx.inscripcionCiclo.update({
              where: { inscripcionId: inscripcion.inscripcionId },
              data: { estadoEnCiclo: 'egresado' }
            });
            await tx.alumno.update({
              where: { alumnoId: alumno.alumnoId },
              data: { estado: 'Egresado' }
            });
            egresados++;
          } else {
            // Promueve al siguiente grado (en el nuevo ciclo, pero aquí solo se deja marcado como promovido)
            await tx.inscripcionCiclo.update({
              where: { inscripcionId: inscripcion.inscripcionId },
              data: { estadoEnCiclo: 'promovido' }
            });
            promovidos++;
          }
        }
      }

      // Marcar ciclo como inactivo (cerrado)
      await tx.cicloEscolar.update({
        where: { cicloId: cicloActivo.cicloId },
        data: { activo: false }
      });

      return { promovidos, egresados, retenidos, cicloCerrado: cicloActivo.nombre };
    });

    res.status(200).json({ 
      ok: true, 
      message: 'Ciclo escolar cerrado con éxito.',
      data: resultado 
    });
  } catch (error) {
    console.error('Error al ejecutar cierre de ciclo:', error);
    res.status(500).json({ ok: false, message: error.message || 'Error al ejecutar cierre de ciclo.' });
  }
}

module.exports = { cerrarCiclo };
