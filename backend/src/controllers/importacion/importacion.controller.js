'use strict';

const alumnosService = require('../../services/alumnos/alumnos.service');
const usuariosService = require('../../services/usuarios/usuarios.service');
const { success } = require('../../utils/response.utils');
const prisma = require('../../config/database');

async function importarAlumnos(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const { alumnos, grupoId } = req.body;
    
    if (!alumnos || !Array.isArray(alumnos)) {
      throw Object.assign(new Error('Debe proporcionar un arreglo de alumnos.'), { statusCode: 400 });
    }

    const cicloActivo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
    let gruposActivos = [];
    if (cicloActivo) {
      gruposActivos = await prisma.grupo.findMany({ 
        where: { cicloId: cicloActivo.cicloId, eliminadoEn: null },
        include: { nivel: true }
      });
    }

    const resultados = { exitosos: 0, fallidos: 0, errores: [] };

    for (const alumno of alumnos) {
      try {
        let resolvedGrupoId = grupoId || alumno.grupoId;
        
        if (!resolvedGrupoId && alumno.grado && alumno.seccion) {
           const matchingGroup = gruposActivos.find(g => 
             g.grado === alumno.grado.toString() &&
             g.seccion.toLowerCase() === alumno.seccion.toLowerCase() &&
             (!alumno.nivel || (g.nivel && g.nivel.codigo.toLowerCase() === alumno.nivel.toLowerCase()))
           );
           if (matchingGroup) {
             resolvedGrupoId = matchingGroup.grupoId;
           }
        }

        await alumnosService.crear({
          ...alumno,
          grupoId: resolvedGrupoId
        }, auditCtx);
        resultados.exitosos++;
      } catch (err) {
        resultados.fallidos++;
        resultados.errores.push(`Error en alumno ${alumno.nombre || alumno.nombreCompleto}: ${err.message}`);
      }
    }

    return success(res, resultados, `Importación completada. Exitosos: ${resultados.exitosos}, Fallidos: ${resultados.fallidos}`);
  } catch (err) {
    next(err);
  }
}

async function importarDocentes(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const { docentes } = req.body;
    
    if (!docentes || !Array.isArray(docentes)) {
      throw Object.assign(new Error('Debe proporcionar un arreglo de docentes.'), { statusCode: 400 });
    }

    const resultados = { exitosos: 0, fallidos: 0, errores: [] };

    for (const docente of docentes) {
      try {
        await usuariosService.crear({
          nombre: docente.nombre,
          username: docente.username,
          password: docente.password || 'Docente123!',
          rol: 'DOCENTE' // O MAESTRA según la bd actual
        }, auditCtx);
        resultados.exitosos++;
      } catch (err) {
        resultados.fallidos++;
        resultados.errores.push(`Error en docente ${docente.nombre}: ${err.message}`);
      }
    }

    return success(res, resultados, `Importación completada. Exitosos: ${resultados.exitosos}, Fallidos: ${resultados.fallidos}`);
  } catch (err) {
    next(err);
  }
}

module.exports = { importarAlumnos, importarDocentes };
