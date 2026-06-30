import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Users, AlertTriangle, TrendingUp, Award, Clock, CreditCard } from 'lucide-react';
import api from '../services/api';

import { useAuthStore } from '../store/useAuthStore';

export function Dashboard() {
  const navigate = useNavigate();
  const { user } = useAuthStore();
  const role = user?.rol?.toUpperCase() || '';
  const isDocente = role === 'DOCENTE' || role === 'MAESTRA';

  const [stats, setStats] = useState({ alumnos: 0, deudores: 0, ingresosHoy: 0, becasActivas: 0 });
  const [ultimosPagos, setUltimosPagos] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    cargarDashboard();
  }, []);

  const cargarDashboard = async () => {
    setLoading(true);
    const newStats = { alumnos: 0, deudores: 0, ingresosHoy: 0, becasActivas: 0 };
    try {
      // 1. Alumnos Activos
      const resAlum = await api.get('/alumnos', { params: { estado: 'Activo', limit: 1, page: 1 } }).catch(() => null);
      if (resAlum?.pagination) {
        newStats.alumnos = resAlum.pagination.total;
      } else if (resAlum?.data?.pagination) {
        newStats.alumnos = resAlum.data.pagination.total;
      } else if (Array.isArray(resAlum?.data)) {
        newStats.alumnos = resAlum.data.length;
      }

      if (!isDocente) {
        // 2. Deudores Activos
        const resDeud = await api.get('/reportes/financieros/deudores').catch(() => null);
        if (Array.isArray(resDeud?.data)) {
          newStats.deudores = resDeud.data.length;
        } else if (Array.isArray(resDeud)) {
          newStats.deudores = resDeud.length;
        }

        // 3. Ingresos del Día
        const hoy = new Date().toISOString().slice(0, 10);
        const resPagos = await api.get('/pagos', { params: { fechaDesde: hoy, fechaHasta: hoy } }).catch(() => null);
        let listaPagos = [];
        if (Array.isArray(resPagos?.data)) {
          listaPagos = resPagos.data;
        } else if (resPagos?.data?.data) {
          listaPagos = resPagos.data.data;
        } else if (Array.isArray(resPagos)) {
          listaPagos = resPagos;
        }
        
        newStats.ingresosHoy = listaPagos.reduce((acc: number, curr: any) => acc + (Number(curr.monto) || 0), 0);
        setUltimosPagos(listaPagos.slice(0, 5));

        // 4. Becas Activas
        const resBecas = await api.get('/becas').catch(() => null);
        if (Array.isArray(resBecas?.data)) {
          newStats.becasActivas = resBecas.data.length;
        } else if (Array.isArray(resBecas)) {
          newStats.becasActivas = resBecas.length;
        }
      }

      setStats(newStats);
    } catch (e) {
      console.error('Error cargando dashboard', e);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      <div className="flex justify-between items-end">
        <div>
          <h2 className="text-2xl font-bold text-navy-800">Dashboard</h2>
          <p className="text-gray-500">Resumen operativo {isDocente ? 'académico' : 'y financiero del día'}</p>
        </div>
        {!isDocente && (
          <button 
            onClick={() => navigate('/pagos')}
            className="flex items-center gap-2 px-6 py-2.5 bg-crimson-600 text-white font-medium rounded-xl hover:bg-crimson-700 transition-colors shadow-sm"
          >
            <CreditCard size={18} /> Pago Rápido
          </button>
        )}
      </div>

      <div className={`grid grid-cols-1 md:grid-cols-2 ${isDocente ? 'lg:grid-cols-1' : 'lg:grid-cols-4'} gap-6`}>
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
          <div className="w-12 h-12 bg-blue-50 text-blue-600 rounded-full flex items-center justify-center">
            <Users size={24} />
          </div>
          <div>
            <h3 className="text-gray-500 text-sm font-medium mb-0.5">Total Alumnos</h3>
            <p className="text-2xl font-bold text-navy-800">
              {loading ? '...' : stats.alumnos}
            </p>
          </div>
        </div>

        {!isDocente && (
          <>
            <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
              <div className="w-12 h-12 bg-emerald-50 text-emerald-600 rounded-full flex items-center justify-center">
                <TrendingUp size={24} />
              </div>
              <div>
                <h3 className="text-gray-500 text-sm font-medium mb-0.5">Ingresos de Hoy</h3>
                <p className="text-2xl font-bold text-navy-800">
                  {loading ? '...' : `$${stats.ingresosHoy.toLocaleString('es-MX', {minimumFractionDigits: 2})}`}
                </p>
              </div>
            </div>

            <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
              <div className="w-12 h-12 bg-red-50 text-red-600 rounded-full flex items-center justify-center">
                <AlertTriangle size={24} />
              </div>
              <div>
                <h3 className="text-gray-500 text-sm font-medium mb-0.5">Deudores Críticos</h3>
                <p className="text-2xl font-bold text-navy-800">
                  {loading ? '...' : stats.deudores}
                </p>
              </div>
            </div>

            <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
              <div className="w-12 h-12 bg-amber-50 text-amber-600 rounded-full flex items-center justify-center">
                <Award size={24} />
              </div>
              <div>
                <h3 className="text-gray-500 text-sm font-medium mb-0.5">Becas Activas</h3>
                <p className="text-2xl font-bold text-navy-800">
                  {loading ? '...' : stats.becasActivas}
                </p>
              </div>
            </div>
          </>
        )}
      </div>
      
      <div className={`grid grid-cols-1 ${isDocente ? '' : 'lg:grid-cols-2'} gap-6`}>
        {!isDocente && (
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex flex-col overflow-hidden">
            <div className="p-5 border-b border-gray-100 flex items-center gap-2 bg-gray-50/50">
              <Clock className="text-gray-400" size={18} />
              <h3 className="font-bold text-navy-800">Últimos Pagos Registrados Hoy</h3>
            </div>
            <div className="flex-1 overflow-auto max-h-[300px]">
              {loading ? (
                <div className="p-8 text-center text-gray-400">Cargando pagos...</div>
              ) : ultimosPagos.length === 0 ? (
                <div className="p-8 text-center text-gray-400">No se han registrado pagos el día de hoy.</div>
              ) : (
                <table className="w-full text-sm text-left">
                  <tbody className="divide-y divide-gray-100">
                    {ultimosPagos.map((p, i) => (
                      <tr key={p.id || i} className="hover:bg-gray-50/80 transition-colors">
                        <td className="p-4 font-bold text-navy-800">{p.alumno?.nombre || p.alumno || 'Desconocido'}</td>
                        <td className="p-4 text-gray-500 text-xs capitalize">{p.concepto?.replace(/_/g, ' ')}</td>
                        <td className="p-4 text-right font-mono font-bold text-emerald-600">
                          ${Number(p.monto).toLocaleString('es-MX', {minimumFractionDigits: 2})}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        )}

        <div className="bg-gradient-to-br from-navy-800 to-navy-900 rounded-2xl shadow-sm border border-navy-700 p-8 flex flex-col justify-center text-white relative overflow-hidden">
          <div className="absolute right-0 top-0 w-64 h-64 bg-white opacity-5 rounded-full -translate-y-1/2 translate-x-1/3"></div>
          <div className="absolute left-0 bottom-0 w-32 h-32 bg-emerald-400 opacity-10 rounded-full translate-y-1/2 -translate-x-1/2"></div>
          
          <h3 className="text-3xl font-black mb-2 relative z-10">Colegio San Diego</h3>
          <p className="text-navy-200 mb-6 relative z-10">Sistema de Administración Escolar (SAE)<br/>Versión React 2026</p>
          
          <div className="flex gap-4 relative z-10 mt-auto pt-4 border-t border-navy-700/50">
            <div className="text-sm">
              <div className="text-navy-300 mb-1">Estado del Sistema</div>
              <div className="flex items-center gap-2 font-bold text-emerald-400">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span> En Línea
              </div>
            </div>
            <div className="text-sm border-l border-navy-700/50 pl-4">
              <div className="text-navy-300 mb-1">Migración</div>
              <div className="font-bold text-white">100% Completada</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
