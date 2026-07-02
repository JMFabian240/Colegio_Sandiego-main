import api from './api';
import type { Tarifa, CicloEscolar, NivelEducativo } from '../types';

export const tarifasService = {
  obtenerCiclos: async (): Promise<{ data: CicloEscolar[] }> => {
    return api.get('/tarifas/ciclos');
  },

  crearCiclo: async (data: Partial<CicloEscolar>): Promise<{ data: CicloEscolar }> => {
    return api.post('/tarifas/ciclos', data);
  },

  obtenerNiveles: async (): Promise<{ data: NivelEducativo[] }> => {
    return api.get('/tarifas/niveles');
  },

  obtenerTarifas: async (cicloId: number, nivelId: number): Promise<{ data: Tarifa[] }> => {
    return api.get('/tarifas', { params: { cicloId, nivelId } });
  },

  guardarTarifas: async (data: { cicloId: number, nivelId: number, tarifas: any[] }): Promise<void> => {
    return api.put('/tarifas', data);
  },

  activarCiclo: async (cicloId: number): Promise<{ data: CicloEscolar }> => {
    return api.put(`/tarifas/${cicloId}/activar`);
  }
};
