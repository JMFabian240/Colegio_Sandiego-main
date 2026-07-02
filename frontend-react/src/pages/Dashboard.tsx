import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Users, AlertTriangle, TrendingUp, Award, Clock, CreditCard, BarChart3, AlertCircle } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, Cell } from 'recharts';
import { alumnosService } from '../services/alumnos.service';
import { reportesService } from '../services/reportes.service';
import { pagosService } from '../services/pagos.service';
import { becasService } from '../services/becas.service';
import { useAuthStore } from '../store/useAuthStore';

export function Dashboard() {
  const navigate = useNavigate();
  const { user } = useAuthStore();
  const role = user?.rol?.toUpperCase() || '';
  const isDocente = role === 'DOCENTE' || role === 'MAESTRA';
  const isAdmin = role === 'ADMIN' || role === 'ADMINISTRADOR';

  const [stats, setStats] = useState({ alumnos: 0, deudores: 0, ingresosHoy: 0, becasActivas: 0 });
  const [ultimosPagos, setUltimosPagos] = useState<any[]>([]);
  const [chartData, setChartData] = useState<any[]>([]);
  const [topDeudores, setTopDeudores] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    cargarDashboard();
  }, []);

  const cargarDashboard = async () => {
    setLoading(true);
    const newStats = { alumnos: 0, deudores: 0, ingresosHoy: 0, becasActivas: 0 };
    try {
      const resAlum: any = await alumnosService.getAlumnos({ estado: 'Activo', limit: 1, page: 1 }).catch(() => null);
      if (resAlum) {
        newStats.alumnos = resAlum.pagination?.total || resAlum.pagination?.totalItems || (Array.isArray(resAlum.data) ? resAlum.data.length : (Array.isArray(resAlum) ? resAlum.length : 0));
      }

      if (isAdmin) {
        const resDeud: any = await reportesService.obtenerDeudores().catch(() => null);
        const deudoresList = resDeud?.data || [];
        
        newStats.deudores = deudoresList.length;
        setTopDeudores(deudoresList.sort((a, b) => Number(b.deudaTotal) - Number(a.deudaTotal)).slice(0, 5));

        const hoyObj = new Date();
        const resPagos: any = await pagosService.obtenerPagos({}).catch(() => null);
        const listaPagos = resPagos?.data || [];
        
        const dateStrHoy = hoyObj.toISOString().slice(0, 10);
        const pagosHoy = listaPagos.filter((p: any) => p.fecha?.startsWith(dateStrHoy));
        
        newStats.ingresosHoy = pagosHoy.reduce((acc: number, curr: any) => acc + (Number(curr.monto) || 0), 0);
        setUltimosPagos(pagosHoy.slice(0, 5));

        const chart = [];
        for (let i = 6; i >= 0; i--) {
          const d = new Date();
          d.setDate(d.getDate() - i);
          const dStr = d.toISOString().slice(0, 10);
          const dayName = d.toLocaleDateString('es-MX', { weekday: 'short' });
          const totalDia = listaPagos.filter((p: any) => p.fecha?.startsWith(dStr)).reduce((acc: any, curr: any) => acc + (Number(curr.monto) || 0), 0);
          chart.push({ name: dayName.charAt(0).toUpperCase() + dayName.slice(1), total: totalDia });
        }
        setChartData(chart);

        const resBecas: any = await becasService.obtenerAsignaciones().catch(() => null);
        newStats.becasActivas = resBecas?.data?.length || 0;
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

        {!isDocente && (
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex flex-col overflow-hidden">
            <div className="p-5 border-b border-gray-100 flex items-center gap-2 bg-gray-50/50">
              <AlertCircle className="text-crimson-500" size={18} />
              <h3 className="font-bold text-navy-800">Top Deudores Críticos</h3>
            </div>
            <div className="flex-1 overflow-auto max-h-[300px]">
              {loading ? (
                <div className="p-8 text-center text-gray-400">Cargando deudores...</div>
              ) : topDeudores.length === 0 ? (
                <div className="p-8 text-center text-emerald-500 font-medium">Sin deudores.</div>
              ) : (
                <table className="w-full text-sm text-left">
                  <tbody className="divide-y divide-gray-100">
                    {topDeudores.map((d, i) => (
                      <tr key={d.alumno?.id || i} className="hover:bg-gray-50/80 transition-colors">
                        <td className="p-4 font-bold text-navy-800">{d.alumno?.nombre || 'Desconocido'}</td>
                        <td className="p-4 text-crimson-600 font-medium text-xs">
                          {d.mesesAtraso} mes{d.mesesAtraso !== 1 ? 'es' : ''} de atraso
                        </td>
                        <td className="p-4 text-right font-mono font-bold text-crimson-600">
                          ${Number(d.deudaTotal).toLocaleString('es-MX', {minimumFractionDigits: 2})}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        )}
      </div>

      {!isDocente && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mt-6">
          <div className="flex items-center gap-2 mb-6">
            <BarChart3 className="text-navy-600" size={20} />
            <h3 className="font-bold text-lg text-navy-800">Ingresos de los últimos 7 días</h3>
          </div>
          <div className="h-72 w-full">
            {loading ? (
              <div className="h-full flex items-center justify-center text-gray-400">Cargando gráfico...</div>
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f3f4f6" />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fill: '#6b7280', fontSize: 12}} dy={10} />
                  <YAxis axisLine={false} tickLine={false} tick={{fill: '#6b7280', fontSize: 12}} tickFormatter={(value) => `$${value}`} />
                  <Tooltip 
                    cursor={{fill: '#f8fafc'}}
                    contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)' }}
                    formatter={(value: number) => [`$${value.toLocaleString('es-MX', {minimumFractionDigits: 2})}`, 'Ingresos']}
                  />
                  <Bar dataKey="total" radius={[6, 6, 0, 0]}>
                    {chartData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.total > 0 ? '#10b981' : '#e2e8f0'} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
