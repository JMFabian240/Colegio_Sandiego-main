import api from './api';
import type { BecaCatalogo, BecaAsignada } from '../types';

export const becasService = {
  obtenerCatalogo: async (): Promise<{ data: BecaCatalogo[] }> => {
    return api.get('/becas/catalogo').catch(() => ({ data: [] }));
  },

  crearEnCatalogo: async (data: Partial<BecaCatalogo>): Promise<{ data: BecaCatalogo }> => {
    return api.post('/becas/catalogo', data);
  },

  actualizarEnCatalogo: async (id: number, data: Partial<BecaCatalogo>): Promise<{ data: BecaCatalogo }> => {
    return api.patch(`/becas/catalogo/${id}`, data);
  },

  eliminarDeCatalogo: async (id: number): Promise<void> => {
    return api.delete(`/becas/catalogo/${id}`);
  },

  obtenerAsignaciones: async (): Promise<{ data: BecaAsignada[] }> => {
    return api.get('/becas').catch(() => ({ data: [] }));
  },

  asignar: async (data: { alumnoId: number, becaId: number, cicloId: number, observaciones?: string }): Promise<{ data: BecaAsignada }> => {
    return api.post('/becas/asignar', data);
  },

  retirar: async (id: number, motivo: string): Promise<void> => {
    return api.post(`/becas/asignaciones/${id}/retirar`, { motivoRetiro: motivo });
  }
};
