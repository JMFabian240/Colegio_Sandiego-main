import api from './api';

export const reportesService = {
  obtenerDeudores: async (): Promise<{ data: any[] }> => {
    return api.get('/reportes/financieros/deudores');
  },

  obtenerReporteAcademico: async (params?: any): Promise<{ data: any }> => {
    return api.get('/reportes/academico', { params });
  }
};
