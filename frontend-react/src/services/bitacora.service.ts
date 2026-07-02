import api from './api';

export const bitacoraService = {
  obtenerRegistros: async (params?: any): Promise<{ data: any[] }> => {
    return api.get('/bitacora', { params });
  }
};
