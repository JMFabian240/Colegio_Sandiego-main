import api from './api';
import type { Pago } from '../types';

export const pagosService = {
  obtenerCalendario: async (alumnoId?: number): Promise<{ data: any[] }> => {
    return api.get('/pagos/calendario', { params: { alumnoId } });
  },

  obtenerPagos: async (params?: any): Promise<{ data: Pago[] }> => {
    return api.get('/pagos', { params });
  },

  registrarPago: async (data: any): Promise<{ data: Pago }> => {
    return api.post('/pagos', data);
  },

  registrarPagoConsolidado: async (data: any): Promise<{ data: any }> => {
    return api.post('/pagos/consolidado', data);
  },

  registrarPagoAdelantado: async (data: any): Promise<{ data: any }> => {
    return api.post('/pagos/adelantado', data);
  },

  subirComprobante: async (pagoId: number, formData: FormData, options?: any): Promise<{ data: any }> => {
    return api.post(`/pagos/${pagoId}/comprobante`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      ...options
    });
  },

  descargarComprobante: async (pagoId: number): Promise<any> => {
    return api.get(`/pagos/${pagoId}/comprobante`, { responseType: 'blob' });
  }
};
