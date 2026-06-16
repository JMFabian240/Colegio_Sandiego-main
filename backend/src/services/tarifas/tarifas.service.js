'use strict';

const prisma = require('../../config/database');

async function listarCiclos() {
  return prisma.cicloEscolar.findMany({
    orderBy: { nombre: 'desc' }
  });
}

async function crearCiclo(data, usuarioId) {
  const { withAudit } = require('../../utils/audit.utils');
  return withAudit(usuarioId, 'IP_AQUI', async (tx) => {
    let previousActiveCycleId = null;
    if (data.activo) {
      const prevActive = await tx.cicloEscolar.findFirst({
        where: { activo: true },
        orderBy: { cicloId: 'desc' }
      });
      if (prevActive) previousActiveCycleId = prevActive.cicloId;

      await tx.cicloEscolar.updateMany({
        where: { activo: true },
        data: { activo: false }
      });
    }

    const nuevoCiclo = await tx.cicloEscolar.create({
      data: {
        nombre: data.nombre,
        fechaInicio: data.fechaInicio ? new Date(data.fechaInicio) : new Date(),
        fechaFin: data.fechaFin ? new Date(data.fechaFin) : new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
        activo: data.activo === undefined ? true : data.activo
      }
    });

    if (previousActiveCycleId) {
      const gruposAnteriores = await tx.grupo.findMany({
        where: { cicloId: previousActiveCycleId, eliminadoEn: null },
        include: { gruposMaterias: true }
      });

      for (const grp of gruposAnteriores) {
        const nuevoGrupo = await tx.grupo.create({
          data: {
            cicloId: nuevoCiclo.cicloId,
            nivelId: grp.nivelId,
            grado: grp.grado,
            seccion: grp.seccion,
            nombre: grp.nombre,
            docenteTitularId: grp.docenteTitularId,
            cupoMaximo: grp.cupoMaximo
          }
        });

        if (grp.gruposMaterias && grp.gruposMaterias.length > 0) {
          const nuevasMaterias = grp.gruposMaterias.map(m => ({
            grupoId: nuevoGrupo.grupoId,
            materiaId: m.materiaId,
            docenteId: m.docenteId,
            horario: m.horario,
            aula: m.aula
          }));
          await tx.grupoMateria.createMany({
            data: nuevasMaterias
          });
        }
      }
    }

    return nuevoCiclo;
  });
}

async function listarNiveles() {
  return prisma.nivelEducativo.findMany({
    orderBy: { nivelId: 'asc' }
  });
}

async function obtenerTarifas(cicloId, nivelId) {
  return prisma.tarifa.findMany({
    where: { 
      cicloId: Number(cicloId),
      nivelId: Number(nivelId)
    }
  });
}

async function guardarTarifas(cicloId, nivelId, tarifas, usuarioId) {
  const ciclo = await prisma.cicloEscolar.findUnique({ where: { cicloId: Number(cicloId) } });
  
  if (!ciclo) {
    throw Object.assign(new Error('Ciclo escolar no encontrado.'), { statusCode: 404 });
  }
  
  if (ciclo.activo === false) {
    throw Object.assign(new Error('No se pueden modificar las tarifas de un ciclo cerrado/inactivo.'), { statusCode: 400 });
  }

  const { withAudit } = require('../../utils/audit.utils');
  
  // Guardamos usando una transacción para que todo o nada pase
  return withAudit(usuarioId, 'IP_AQUI', async (tx) => {
    const resultados = [];
    
    for (const item of tarifas) {
      if (!item.concepto || isNaN(item.monto) || Number(item.monto) <= 0) {
        throw Object.assign(new Error(`Monto inválido para el concepto ${item.concepto}. Debe ser mayor a 0.`), { statusCode: 400 });
      }

      // Upsert
      const conceptoLower = item.concepto.toLowerCase();
      
      const tarifaExistente = await tx.tarifa.findFirst({
        where: { cicloId: Number(cicloId), nivelId: Number(nivelId), concepto: conceptoLower }
      });
      
      if (tarifaExistente) {
        const t = await tx.tarifa.update({
          where: { tarifaId: tarifaExistente.tarifaId },
          data: { monto: Number(item.monto) }
        });
        resultados.push(t);
      } else {
        const t = await tx.tarifa.create({
          data: {
            cicloId: Number(cicloId),
            nivelId: Number(nivelId),
            concepto: conceptoLower,
            monto: Number(item.monto)
          }
        });
        resultados.push(t);
      }
    }
    
    return resultados;
  });
}

module.exports = {
  listarCiclos,
  crearCiclo,
  listarNiveles,
  obtenerTarifas,
  guardarTarifas
};
