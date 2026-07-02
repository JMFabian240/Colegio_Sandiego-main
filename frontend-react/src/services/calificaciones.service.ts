import api from './api';
import type { Calificacion } from '../types';

export const calificacionesService = {
  obtenerPorAlumno: async (alumnoId: number): Promise<{ data: Calificacion[] }> => {
    return api.get(`/calificaciones/alumno/${alumnoId}`);
  },

  obtenerPorGrupoMateria: async (grupoMateriaId: number): Promise<{ data: Calificacion[] }> => {
    return api.get('/calificaciones', { params: { grupoMateriaId, limit: 1000 } });
  },

  guardarLote: async (calificaciones: any[]): Promise<{ data: any }> => {
    return api.post('/calificaciones/lote', { calificaciones });
  }
};
