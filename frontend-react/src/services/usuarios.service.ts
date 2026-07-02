import api from './api';
import type { Usuario } from '../types';

export const usuariosService = {
  obtenerTodos: async (params?: any): Promise<{ data: Usuario[] }> => {
    return api.get('/usuarios', { params });
  },
  
  obtenerPorId: async (id: number): Promise<{ data: Usuario }> => {
    return api.get(`/usuarios/${id}`);
  },

  crear: async (data: Partial<Usuario>): Promise<{ data: Usuario }> => {
    return api.post('/usuarios', data);
  },

  actualizar: async (id: number, data: Partial<Usuario>): Promise<{ data: Usuario }> => {
    return api.put(`/usuarios/${id}`, data);
  },

  eliminar: async (id: number): Promise<void> => {
    return api.delete(`/usuarios/${id}`);
  },

  reactivar: async (id: number): Promise<void> => {
    return api.put(`/usuarios/${id}/reactivar`, {});
  },

  cambiarPassword: async (id: number, password: string): Promise<void> => {
    return api.put(`/usuarios/${id}`, { password });
  },

  obtenerRoles: async (): Promise<{ data: any[] }> => {
    return api.get('/permisos/roles');
  },

  obtenerModulos: async (): Promise<{ data: any[] }> => {
    return api.get('/permisos/modulos');
  },

  obtenerPermisosUsuario: async (id: number): Promise<{ data: any[] }> => {
    return api.get(`/permisos/usuarios/${id}`);
  },

  actualizarPermisosUsuario: async (id: number, permisos: string[]): Promise<void> => {
    return api.put(`/permisos/usuarios/${id}`, { permisos });
  }
};
