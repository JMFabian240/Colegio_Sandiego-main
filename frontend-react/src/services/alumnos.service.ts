import api from './api';
import type { Alumno } from '../types';

export const alumnosService = {
  getAlumnos: async (params?: any): Promise<Alumno[]> => {
    const res = await api.get('/alumnos', { params });
    // Assuming backend returns data directly, or maybe in res.data if intercepted
    return res.data || res;
  },

  getAlumnoById: async (id: number): Promise<Alumno> => {
    const res = await api.get(`/alumnos/${id}`);
    return res.data || res;
  },

  createAlumno: async (data: Partial<Alumno>): Promise<Alumno> => {
    const res = await api.post('/alumnos', data);
    return res.data || res;
  },

  updateAlumno: async (id: number, data: Partial<Alumno>): Promise<Alumno> => {
    const res = await api.put(`/alumnos/${id}`, data);
    return res.data || res;
  },

  deleteAlumno: async (id: number): Promise<void> => {
    await api.delete(`/alumnos/${id}`);
  }
};
