import api from './api';
import type { Tutor } from '../types';

export const tutoresService = {
  getTutores: async (params?: any): Promise<Tutor[]> => {
    const res = await api.get('/tutores', { params });
    return res.data || res;
  },

  getTutorById: async (id: number): Promise<Tutor> => {
    const res = await api.get(`/tutores/${id}`);
    return res.data || res;
  },

  createTutor: async (data: Partial<Tutor>): Promise<Tutor> => {
    const res = await api.post('/tutores', data);
    return res.data || res;
  },

  updateTutor: async (id: number, data: Partial<Tutor>): Promise<Tutor> => {
    const res = await api.put(`/tutores/${id}`, data);
    return res.data || res;
  },

  vincularAlumno: async (tutorId: number, data: { alumnoId: number; tipoRelacion: string; esResponsableFinanciero: boolean; puedeRecoger: boolean }): Promise<any> => {
    const res = await api.post(`/tutores/${tutorId}/vincular`, data);
    return res.data || res;
  }
};
