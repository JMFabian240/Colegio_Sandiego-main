import api from './api';
import type { Grupo, Usuario } from '../types';

export const gruposService = {
  obtenerTodos: async (params?: any): Promise<{ data: Grupo[] }> => {
    return api.get('/grupos', { params });
  },

  obtenerPorId: async (id: number): Promise<{ data: Grupo }> => {
    return api.get(`/grupos/${id}`);
  },

  crear: async (data: Partial<Grupo>): Promise<{ data: Grupo }> => {
    return api.post('/grupos', data);
  },

  actualizar: async (id: number, data: Partial<Grupo>): Promise<{ data: Grupo }> => {
    return api.put(`/grupos/${id}`, data);
  },

  eliminar: async (id: number): Promise<void> => {
    return api.delete(`/grupos/${id}`);
  },

  obtenerDocentes: async (): Promise<{ data: Usuario[] }> => {
    return api.get('/usuarios', { params: { rol: 'MAESTRA' } });
  },

  obtenerAlumnosMateria: async (materiaId: number): Promise<{ data: any[] }> => {
    return api.get(`/grupos/materias/${materiaId}/alumnos`);
  },

  asignarAlumnosMateria: async (materiaId: number, alumnosIds: number[]): Promise<void> => {
    return api.put(`/grupos/materias/${materiaId}/alumnos`, { alumnosIds });
  }
};
