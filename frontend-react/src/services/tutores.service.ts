import api from './api';
import type { Tutor } from '../types';

export const tutoresService = {
  getTutores: async (params?: any): Promise<any> => {
    return api.get('/tutores', { params });
  },

  getTutorById: async (id: number): Promise<any> => {
    return api.get(`/tutores/${id}`);
  },

  createTutor: async (data: Partial<Tutor>): Promise<any> => {
    return api.post('/tutores', data);
  },

  updateTutor: async (id: number, data: Partial<Tutor>): Promise<any> => {
    return api.put(`/tutores/${id}`, data);
  },

  vincularAlumno: async (tutorId: number, data: { alumnoId: number; tipoRelacion: string; esResponsableFinanciero: boolean; puedeRecoger: boolean }): Promise<any> => {
    return api.post(`/tutores/${tutorId}/vincular`, data);
  },

  desvincularAlumno: async (tutorId: number, alumnoId: number): Promise<void> => {
    return api.delete(`/tutores/${tutorId}/desvincular/${alumnoId}`);
  }
};
