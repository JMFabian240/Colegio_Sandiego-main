import api from './api';
import type { Alumno } from '../types';

export const alumnosService = {
  getAlumnos: async (params?: any): Promise<any> => {
    return api.get('/alumnos', { params });
  },

  getEstadoCuenta: async (id: number): Promise<any> => {
    return api.get(`/alumnos/${id}/estado-cuenta`);
  },

  previewPlanPagos: async (id: number, meses: number): Promise<any> => {
    return api.get(`/alumnos/${id}/planes/preview?meses=${meses}`);
  },

  generarPlanPagos: async (id: number, meses: number): Promise<any> => {
    return api.post(`/alumnos/${id}/planes`, { meses });
  },

  eliminarPlanPagos: async (id: number): Promise<any> => {
    return api.delete(`/alumnos/${id}/planes`);
  },

  getAlumnoById: async (id: number): Promise<any> => {
    return api.get(`/alumnos/${id}`);
  },

  createAlumno: async (data: Partial<Alumno>): Promise<any> => {
    return api.post('/alumnos', data);
  },

  updateAlumno: async (id: number, data: Partial<Alumno>): Promise<any> => {
    return api.put(`/alumnos/${id}`, data);
  },

  deleteAlumno: async (id: number): Promise<void> => {
    return api.delete(`/alumnos/${id}`);
  },

  obtenerEstadoCuenta: async (id: number): Promise<any> => {
    return api.get(`/alumnos/${id}/estado-cuenta`);
  },

  obtenerPreviewPlanes: async (id: number, meses: number): Promise<any> => {
    return api.get(`/alumnos/${id}/planes/preview?meses=${meses}`);
  },

  crearPlan: async (id: number, meses: number): Promise<any> => {
    return api.post(`/alumnos/${id}/planes`, { meses });
  },

  eliminarPlanes: async (id: number): Promise<void> => {
    return api.delete(`/alumnos/${id}/planes`);
  },

  obtenerHistorialAcademico: async (id: number): Promise<any> => {
    return api.get(`/alumnos/${id}/historial-academico`);
  },

  cerrarCiclo: async (): Promise<any> => {
    return api.post('/alumnos/cierre-ciclo');
  }
};
