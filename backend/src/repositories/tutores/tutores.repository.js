'use strict';

const prisma = require('../../config/database');

async function findAll(filtros = {}) {
  const { q, activo, page, limit } = filtros;
  
  const where = {};
  
  if (activo !== undefined) {
    where.activo = activo;
  }
  
  if (q) {
    where.OR = [
      { nombreCompleto: { contains: q, mode: 'insensitive' } },
      { correoElectronico: { contains: q, mode: 'insensitive' } },
      { rfc: { contains: q, mode: 'insensitive' } },
      { curp: { contains: q, mode: 'insensitive' } }
    ];
  }

  // Si no hay paginación, devuelve todos
  if (!page || !limit) {
    return prisma.tutor.findMany({
      where,
      include: { alumnos: { select: { alumnoId: true } } },
      orderBy: { nombreCompleto: 'asc' },
    });
  }

  const offset = (page - 1) * limit;
  const [total, data] = await Promise.all([
    prisma.tutor.count({ where }),
    prisma.tutor.findMany({
      where,
      skip: offset,
      take: limit,
      include: { alumnos: { select: { alumnoId: true } } },
      orderBy: { nombreCompleto: 'asc' },
    })
  ]);

  return {
    data,
    pagination: {
      total,
      page,
      limit,
      pages: Math.ceil(total / limit) || 1
    }
  };
}

async function findById(id) {
  return prisma.tutor.findUnique({
    where: { tutorId: Number(id) },
    include: {
      alumnos: {
        where: { activo: true },
        include: {
          alumno: {
            select: {
              alumnoId: true,
              matricula: true,
              nombreCompleto: true,
              nivel: { select: { nombre: true } },
              estado: true
            }
          }
        }
      }
    }
  });
}

async function findByRfc(rfc) {
  return prisma.tutor.findUnique({
    where: { rfc }
  });
}

async function create(datos, auditCtx) {
  const result = await prisma.tutor.create({
    data: datos
  });

  if (auditCtx?.usuarioId) {
    await prisma.logAuditoria.create({
      data: {
        usuarioId: auditCtx.usuarioId,
        accion: 'INSERT',
        tablaAfectada: 'tutor',
        registroId: result.tutorId.toString(),
        valoresDespues: result,
        direccionIp: auditCtx.ip
      }
    });
  }

  return result;
}

async function update(id, datos, auditCtx) {
  const antes = await prisma.tutor.findUnique({ where: { tutorId: Number(id) } });
  
  const result = await prisma.tutor.update({
    where: { tutorId: Number(id) },
    data: datos
  });

  if (auditCtx?.usuarioId) {
    await prisma.logAuditoria.create({
      data: {
        usuarioId: auditCtx.usuarioId,
        accion: 'UPDATE',
        tablaAfectada: 'tutor',
        registroId: id.toString(),
        valoresAntes: antes,
        valoresDespues: result,
        direccionIp: auditCtx.ip
      }
    });
  }

  return result;
}

async function softDelete(id, auditCtx) {
  const antes = await prisma.tutor.findUnique({ where: { tutorId: Number(id) } });
  
  const result = await prisma.tutor.update({
    where: { tutorId: Number(id) },
    data: {
      activo: false,
      eliminadoEn: new Date()
    }
  });

  if (auditCtx?.usuarioId) {
    await prisma.logAuditoria.create({
      data: {
        usuarioId: auditCtx.usuarioId,
        accion: 'DELETE',
        tablaAfectada: 'tutor',
        registroId: id.toString(),
        valoresAntes: antes,
        valoresDespues: result,
        direccionIp: auditCtx.ip
      }
    });
  }

  return result;
}

async function vincularAlumno(tutorId, alumnoId, opciones = {}, auditCtx) {
  const result = await prisma.tutorAlumno.upsert({
    where: {
      tutorId_alumnoId: {
        tutorId: Number(tutorId),
        alumnoId: Number(alumnoId)
      }
    },
    update: {
      tipoRelacion: opciones.tipoRelacion || 'tutor',
      esResponsableFinanciero: opciones.esResponsableFinanciero !== undefined ? opciones.esResponsableFinanciero : true,
      activo: true
    },
    create: {
      tutorId: Number(tutorId),
      alumnoId: Number(alumnoId),
      tipoRelacion: opciones.tipoRelacion || 'tutor',
      esResponsableFinanciero: opciones.esResponsableFinanciero !== undefined ? opciones.esResponsableFinanciero : true,
      puedeRecoger: true,
      recibeNotificaciones: true,
      activo: true
    }
  });

  if (auditCtx?.usuarioId) {
    await prisma.logAuditoria.create({
      data: {
        usuarioId: auditCtx.usuarioId,
        accion: 'INSERT',
        tablaAfectada: 'tutor_alumno',
        registroId: result.tutorAlumnoId.toString(),
        valoresDespues: result,
        direccionIp: auditCtx.ip
      }
    });
  }

  return result;
}

async function desvincularAlumno(tutorId, alumnoId, auditCtx) {
  const relacion = await prisma.tutorAlumno.findUnique({
    where: { tutorId_alumnoId: { tutorId: Number(tutorId), alumnoId: Number(alumnoId) } }
  });

  if (!relacion) return null;

  const result = await prisma.tutorAlumno.update({
    where: { tutorId_alumnoId: { tutorId: Number(tutorId), alumnoId: Number(alumnoId) } },
    data: { activo: false, eliminadoEn: new Date() }
  });

  if (auditCtx?.usuarioId) {
    await prisma.logAuditoria.create({
      data: {
        usuarioId: auditCtx.usuarioId,
        accion: 'DELETE',
        tablaAfectada: 'tutor_alumno',
        registroId: result.tutorAlumnoId.toString(),
        valoresAntes: relacion,
        valoresDespues: result,
        direccionIp: auditCtx.ip
      }
    });
  }

  return result;
}

module.exports = {
  findAll,
  findById,
  findByRfc,
  create,
  update,
  softDelete,
  vincularAlumno,
  desvincularAlumno
};
