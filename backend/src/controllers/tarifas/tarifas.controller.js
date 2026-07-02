'use strict';

const tarifasService = require('../../services/tarifas/tarifas.service');

async function listarCiclos(req, res, next) {
  try {
    const ciclos = await tarifasService.listarCiclos();
    res.json({ ok: true, data: ciclos });
  } catch (err) { next(err); }
}

async function crearCiclo(req, res, next) {
  try {
    const { nombre, fechaInicio, fechaFin, activo } = req.body;
    if (!nombre) {
      return res.status(400).json({ ok: false, message: 'El nombre del ciclo es obligatorio.' });
    }
    const nuevoCiclo = await tarifasService.crearCiclo({ nombre, fechaInicio, fechaFin, activo }, req.usuario?.id);
    res.json({ ok: true, data: nuevoCiclo, message: 'Ciclo escolar creado exitosamente.' });
  } catch (err) { next(err); }
}

async function listarNiveles(req, res, next) {
  try {
    const niveles = await tarifasService.listarNiveles();
    res.json({ ok: true, data: niveles });
  } catch (err) { next(err); }
}

async function obtenerTarifas(req, res, next) {
  try {
    const { cicloId, nivelId } = req.query;
    if (!cicloId || !nivelId) {
      return res.status(400).json({ ok: false, message: 'Se requiere cicloId y nivelId.' });
    }
    const tarifas = await tarifasService.obtenerTarifas(cicloId, nivelId);
    res.json({ ok: true, data: tarifas });
  } catch (err) { next(err); }
}

async function guardarTarifas(req, res, next) {
  try {
    const { cicloId, nivelId, tarifas } = req.body;
    
    if (!cicloId || !nivelId || !Array.isArray(tarifas) || tarifas.length === 0) {
      return res.status(400).json({ ok: false, message: 'Datos incompletos.' });
    }

    const resultados = await tarifasService.guardarTarifas(cicloId, nivelId, tarifas, req.usuario?.id);
    
    res.json({ 
      ok: true, 
      message: 'Tarifas guardadas exitosamente.',
      data: resultados 
    });
  } catch (err) { next(err); }
}

async function activarCiclo(req, res, next) {
  try {
    const { id } = req.params;
    const ciclo = await tarifasService.activarCiclo(id);
    res.json({ ok: true, data: ciclo, message: 'Ciclo escolar activado exitosamente.' });
  } catch (err) { next(err); }
}

module.exports = {
  listarCiclos,
  crearCiclo,
  activarCiclo,
  listarNiveles,
  obtenerTarifas,
  guardarTarifas
};
