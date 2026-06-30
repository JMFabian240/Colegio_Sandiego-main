import React, { useState, useEffect } from 'react';
import { BarChart3, Download, DollarSign, Users, FileText, AlertTriangle } from 'lucide-react';
import api from '../services/api';

export function Reportes() {
  const [tabActual, setTabActual] = useState<'caja' | 'ingresos' | 'deudores' | 'facturables'>('caja');
  
  const [corteCaja, setCorteCaja] = useState<any>(null);
  const [ingresos, setIngresos] = useState<any>(null);
  const [deudores, setDeudores] = useState<any[]>([]);
  const [facturables, setFacturables] = useState<any[]>([]);
  
  const [ciclos, setCiclos] = useState<any[]>([]);
  const [cicloSeleccionado, setCicloSeleccionado] = useState('');
  
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    cargarCiclos();
  }, []);

  useEffect(() => {
    if (tabActual === 'caja' && !corteCaja) cargarCorteCaja();
    if (tabActual === 'ingresos') cargarIngresos();
    if (tabActual === 'deudores' && deudores.length === 0) cargarDeudores();
    if (tabActual === 'facturables' && facturables.length === 0) cargarFacturables();
  }, [tabActual, cicloSeleccionado]);

  const cargarCiclos = async () => {
    try {
      const res = await api.get('/tarifas/ciclos');
      if (res.data) setCiclos(res.data);
    } catch (e) {
      console.warn('Error cargando ciclos', e);
    }
  };

  const cargarCorteCaja = async () => {
    setLoading(true);
    try {
      const res = await api.get('/reportes/corte-caja');
      setCorteCaja(res.data);
    } catch (e) { console.error('Error cargando corte caja', e); }
    finally { setLoading(false); }
  };

  const cargarIngresos = async () => {
    setLoading(true);
    try {
      const res = await api.get('/reportes/ingresos-mensuales', { params: { cicloId: cicloSeleccionado }});
      setIngresos(res.data);
    } catch (e) { console.error('Error cargando ingresos', e); }
    finally { setLoading(false); }
  };

  const cargarDeudores = async () => {
    setLoading(true);
    try {
      const res = await api.get('/reportes/deudores');
      setDeudores(res.data || []);
    } catch (e) { console.error('Error cargando deudores', e); }
    finally { setLoading(false); }
  };

  const cargarFacturables = async () => {
    setLoading(true);
    try {
      const res = await api.get('/reportes/facturables');
      setFacturables(res.data || []);
    } catch (e) { console.error('Error cargando facturables', e); }
    finally { setLoading(false); }
  };

  const exportarCSV = (filename: string, content: string) => {
    const blob = new Blob(['\uFEFF' + content], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleExportarCorte = () => {
    if (!corteCaja?.pagos?.length) return alert('No hay datos');
    const head = 'Alumno,Matrícula,Método,Registrado por,Monto\n';
    const rows = corteCaja.pagos.map((p:any) => `"${p.alumno}","${p.matricula}","${p.metodoPago}","${p.registradoPor}",${p.monto}`).join('\n');
    exportarCSV(`Corte_Caja_${corteCaja.fecha || 'hoy'}.csv`, head + rows);
  };

  const handleExportarDeudores = () => {
    if (!deudores.length) return alert('No hay datos');
    const head = 'Alumno,Matrícula,Nivel,Meses Adeudo,Monto Total,Sanción\n';
    const rows = deudores.map((d:any) => `"${d.nombre}","${d.matricula}","${d.nivel}",${d.mesesAdeudo},${d.montoTotal},"${d.sancion}"`).join('\n');
    exportarCSV('Deudores.csv', head + rows);
  };

  const getSancionStyles = (sancion: string) => {
    if (sancion === 'Baja temporal') return 'bg-red-100 text-red-700';
    if (sancion === 'Examen restringido') return 'bg-amber-100 text-amber-700';
    return 'bg-gray-100 text-gray-700';
  };

  return (
    <div className="h-full flex flex-col relative overflow-hidden">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-navy-800 flex items-center gap-2">
          <BarChart3 className="text-navy-600" /> Reportes Financieros
        </h2>
        <p className="text-sm text-gray-500 mt-1">Métricas, ingresos, cortes de caja y seguimiento de deudores.</p>
      </div>

      <div className="flex gap-2 mb-6 overflow-x-auto pb-1">
        {[
          { id: 'caja', label: 'Corte de Caja', icon: DollarSign },
          { id: 'ingresos', label: 'Ingresos Mensuales', icon: BarChart3 },
          { id: 'deudores', label: 'Deudores', icon: AlertTriangle },
          { id: 'facturables', label: 'Padres Facturables', icon: FileText }
        ].map(tab => (
          <button 
            key={tab.id}
            onClick={() => setTabActual(tab.id as any)}
            className={`flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-medium transition-all whitespace-nowrap ${
              tabActual === tab.id 
                ? 'bg-navy-600 text-white shadow-sm' 
                : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'
            }`}
          >
            <tab.icon size={16} /> {tab.label}
          </button>
        ))}
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 flex flex-col overflow-hidden">
        {loading && <div className="absolute inset-0 bg-white/50 backdrop-blur-[1px] z-10 flex items-center justify-center text-navy-600 font-medium">Cargando datos...</div>}
        
        {/* CORTE DE CAJA */}
        {tabActual === 'caja' && (
          <div className="flex flex-col h-full p-6">
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-lg font-bold text-navy-800">
                Corte de Caja del Día — <span className="font-normal text-gray-500">{corteCaja?.fecha}</span>
              </h3>
              <button 
                onClick={handleExportarCorte}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-navy-700 bg-navy-50 rounded-lg hover:bg-navy-100 transition-colors"
              >
                <Download size={16} /> Exportar CSV
              </button>
            </div>

            <div className="grid grid-cols-3 gap-6 mb-8">
              <div className="bg-gradient-to-br from-navy-50 to-navy-100/50 p-6 rounded-2xl border border-navy-50">
                <div className="text-sm font-medium text-navy-600/80 mb-1">Total recaudado</div>
                <div className="text-3xl font-black text-navy-800">
                  ${(corteCaja?.resumen?.total || 0).toLocaleString('es-MX', {minimumFractionDigits: 2})}
                </div>
              </div>
              <div className="bg-emerald-50 p-6 rounded-2xl border border-emerald-100/50">
                <div className="text-sm font-medium text-emerald-600/80 mb-1">Pagos registrados</div>
                <div className="text-3xl font-black text-emerald-800">{corteCaja?.cantidadPagos || 0}</div>
              </div>
              <div className="bg-indigo-50 p-6 rounded-2xl border border-indigo-100/50">
                <div className="text-sm font-medium text-indigo-600/80 mb-1">Por transferencia</div>
                <div className="text-3xl font-black text-indigo-800">
                  ${(corteCaja?.resumen?.porMetodo?.transferencia || 0).toLocaleString('es-MX', {minimumFractionDigits: 2})}
                </div>
              </div>
            </div>

            <div className="flex-1 overflow-auto -mx-6 px-6">
              <table className="w-full text-sm text-left">
                <thead className="bg-gray-50 text-gray-600 sticky top-0">
                  <tr>
                    <th className="p-4 font-semibold rounded-tl-lg">Alumno</th>
                    <th className="p-4 font-semibold">Matrícula</th>
                    <th className="p-4 font-semibold">Método</th>
                    <th className="p-4 font-semibold">Cajero</th>
                    <th className="p-4 font-semibold text-right rounded-tr-lg">Monto</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {(!corteCaja?.pagos || corteCaja.pagos.length === 0) && (
                    <tr><td colSpan={5} className="p-8 text-center text-gray-400">Sin pagos registrados hoy.</td></tr>
                  )}
                  {corteCaja?.pagos?.map((p: any) => (
                    <tr key={p.pagoId} className="hover:bg-gray-50/50">
                      <td className="p-4 font-bold text-navy-800">{p.alumno}</td>
                      <td className="p-4 font-mono text-gray-500">{p.matricula}</td>
                      <td className="p-4"><span className="bg-gray-100 px-2 py-1 rounded text-xs font-semibold">{p.metodoPago}</span></td>
                      <td className="p-4 text-gray-500">{p.registradoPor}</td>
                      <td className="p-4 text-right font-mono font-bold text-emerald-600">${p.monto.toLocaleString('es-MX', {minimumFractionDigits:2})}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* INGRESOS MENSUALES */}
        {tabActual === 'ingresos' && (
          <div className="flex flex-col h-full p-6">
             <div className="flex justify-between items-center mb-6">
              <div className="flex items-center gap-4">
                <h3 className="text-lg font-bold text-navy-800">
                  Ingresos Mensuales <span className="font-normal text-gray-500">{ingresos?.anio}</span>
                </h3>
                <select 
                  className="px-3 py-1.5 rounded-lg border border-gray-200 text-sm focus:ring-2 focus:ring-navy-500 outline-none"
                  value={cicloSeleccionado}
                  onChange={e => setCicloSeleccionado(e.target.value)}
                >
                  <option value="">Año Actual (Global)</option>
                  {ciclos.map(c => <option key={c.cicloId} value={c.cicloId}>{c.nombre}</option>)}
                </select>
              </div>
              <div className="text-xl font-bold text-emerald-700 bg-emerald-50 px-4 py-2 rounded-xl">
                Total anual: ${(ingresos?.totalAnual || 0).toLocaleString('es-MX', {minimumFractionDigits:2})}
              </div>
            </div>

            <div className="flex-1 overflow-auto -mx-6 px-6">
              <table className="w-full text-sm text-left">
                <thead className="bg-gray-50 text-gray-600 sticky top-0">
                  <tr>
                    <th className="p-4 font-semibold rounded-tl-lg">Mes</th>
                    <th className="p-4 font-semibold text-right rounded-tr-lg">Ingresos Totales</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {Object.entries(ingresos?.meses || {}).map(([mes, monto]: any) => (
                    <tr key={mes} className="hover:bg-gray-50/50">
                      <td className="p-4 font-bold text-navy-800 capitalize">{mes}</td>
                      <td className="p-4 text-right font-mono font-bold text-emerald-600">${monto.toLocaleString('es-MX', {minimumFractionDigits:2})}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* DEUDORES */}
        {tabActual === 'deudores' && (
          <div className="flex flex-col h-full p-6">
             <div className="flex justify-between items-center mb-6">
              <h3 className="text-lg font-bold text-navy-800">Monitor de Morosidad</h3>
              <button 
                onClick={handleExportarDeudores}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-navy-700 bg-navy-50 rounded-lg hover:bg-navy-100 transition-colors"
              >
                <Download size={16} /> Exportar CSV
              </button>
            </div>

            <div className="flex-1 overflow-auto -mx-6 px-6">
              <table className="w-full text-sm text-left">
                <thead className="bg-gray-50 text-gray-600 sticky top-0">
                  <tr>
                    <th className="p-4 font-semibold rounded-tl-lg">Alumno</th>
                    <th className="p-4 font-semibold">Nivel</th>
                    <th className="p-4 font-semibold text-center">Meses Adeudo</th>
                    <th className="p-4 font-semibold text-right">Monto Adeudado</th>
                    <th className="p-4 font-semibold rounded-tr-lg">Sanción Activa</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {deudores.length === 0 && (
                    <tr><td colSpan={5} className="p-8 text-center text-gray-400">No hay deudores registrados.</td></tr>
                  )}
                  {deudores.map(d => (
                    <tr key={d.alumnoId} className={`hover:bg-gray-50/50 ${d.mesesAdeudo >= 3 ? 'bg-red-50/30' : d.mesesAdeudo === 2 ? 'bg-amber-50/30' : ''}`}>
                      <td className="p-4">
                        <div className="font-bold text-navy-800">{d.nombre}</div>
                        <div className="font-mono text-xs text-gray-500 mt-0.5">{d.matricula}</div>
                      </td>
                      <td className="p-4 text-gray-600">{d.nivel}</td>
                      <td className="p-4 text-center">
                        <span className={`font-black text-lg ${d.mesesAdeudo >= 3 ? 'text-red-600' : d.mesesAdeudo === 2 ? 'text-amber-600' : 'text-gray-700'}`}>
                          {d.mesesAdeudo}
                        </span>
                      </td>
                      <td className="p-4 text-right font-mono font-bold text-red-600">
                        ${d.montoTotal.toLocaleString('es-MX', {minimumFractionDigits:2})}
                      </td>
                      <td className="p-4">
                        <span className={`px-3 py-1 rounded-full text-xs font-bold ${getSancionStyles(d.sancion)}`}>
                          {d.sancion}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* FACTURABLES */}
        {tabActual === 'facturables' && (
          <div className="flex flex-col h-full p-6 text-center justify-center">
            <FileText className="w-16 h-16 text-gray-200 mx-auto mb-4" />
            <h3 className="text-lg font-bold text-navy-800 mb-2">Padres Facturables</h3>
            <p className="text-gray-500 mb-6">Módulo en proceso de refactorización visual.</p>
            <div className="text-left bg-gray-50 p-4 rounded-xl border border-gray-100 inline-block mx-auto">
              Total de registros: <span className="font-bold">{facturables.length}</span>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}
