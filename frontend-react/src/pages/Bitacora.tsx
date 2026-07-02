import React, { useState, useEffect } from 'react';
import { History, RefreshCw, Download, FileText, X } from 'lucide-react';
import api from '../services/api';

export function Bitacora() {
  const [logs, setLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalRecords, setTotalRecords] = useState(0);
  
  // Filtros
  const [filtros, setFiltros] = useState({
    fechaInicio: '',
    fechaFin: '',
    rol: '',
    accion: '',
    usuarioId: ''
  });
  const [usuariosDisp, setUsuariosDisp] = useState<any[]>([]);

  const limit = 20;

  useEffect(() => {
    cargarUsuarios();
  }, []);

  useEffect(() => {
    cargarBitacora(page);
  }, [page, filtros]);

  const cargarUsuarios = async () => {
    try {
      const res = await api.get('/usuarios');
      setUsuariosDisp(res.data?.datos || res.data || []);
    } catch(e) {}
  };

  const cargarBitacora = async (pagina = 1) => {
    setLoading(true);
    try {
      const params: any = { pagina, limite: limit };
      if (filtros.fechaInicio) params.fechaInicio = filtros.fechaInicio;
      if (filtros.fechaFin) params.fechaFin = filtros.fechaFin;
      if (filtros.rol) params.rol = filtros.rol;
      if (filtros.accion) params.accion = filtros.accion;
      if (filtros.usuarioId) params.usuarioId = filtros.usuarioId;
      
      const res = await api.get('/bitacora', { params });
      const data = res.data;
      if (data && data.datos) {
        setLogs(data.datos);
        setPage(data.pagina || 1);
        setTotalPages(Math.ceil((data.total || 0) / limit) || 1);
        setTotalRecords(data.total || 0);
      } else {
        // Fallback for different API structure
        setLogs(Array.isArray(data) ? data : []);
      }
    } catch (error) {
      console.error('Error cargando bitácora', error);
    } finally {
      setLoading(false);
    }
  };

  const getActionColor = (accion: string) => {
    const act = accion?.toLowerCase() || '';
    if (act.includes('crea')) return 'text-emerald-600';
    if (act.includes('modif') || act.includes('actua')) return 'text-amber-600';
    if (act.includes('elim')) return 'text-red-600';
    return 'text-navy-600';
  };

  const exportarCSV = () => {
    if (!logs.length) return alert('No hay datos para exportar.');
    const headers = 'ID,Fecha,Usuario,Rol,Acción,Entidad,Detalle\n';
    const rows = logs.map(log => 
      `${log.logId},"${new Date(log.fechaHora).toLocaleString('es-MX')}","${log.usuario}","${log.rol}","${log.tipoAccion}","${log.entidad}","${log.detalle?.replace(/"/g, '""') || ''}"`
    ).join('\n');
    
    const blob = new Blob(['\uFEFF' + headers + rows], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `Bitacora_Auditoria_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="h-full flex flex-col relative overflow-hidden">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-navy-800 flex items-center gap-2">
            <History className="text-navy-600" /> Bitácora del Sistema
          </h2>
          <p className="text-sm text-gray-500 mt-1">Auditoría transaccional de todas las acciones del personal.</p>
        </div>
        <div className="flex gap-3">
          <button 
            onClick={() => {
              setFiltros({ fechaInicio: '', fechaFin: '', rol: '', accion: '', usuarioId: '' });
              setPage(1);
            }}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2 bg-white text-gray-500 border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors shadow-sm font-medium disabled:opacity-50"
          >
            <X size={16} /> Limpiar Filtros
          </button>
          <button 
            onClick={() => cargarBitacora(page)}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2 bg-white text-navy-700 border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors shadow-sm font-medium disabled:opacity-50"
          >
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} /> Actualizar
          </button>
          <button 
            onClick={exportarCSV}
            className="flex items-center gap-2 px-4 py-2 bg-navy-600 text-white rounded-xl hover:bg-navy-700 transition-colors shadow-sm font-medium"
          >
            <Download size={16} /> Exportar CSV
          </button>
        </div>
      </div>

      <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 mb-4 grid grid-cols-5 gap-4">
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Desde</label>
          <input type="date" className="w-full px-3 py-2 rounded-xl border border-gray-200 text-sm outline-none focus:ring-2 focus:ring-navy-500" value={filtros.fechaInicio} onChange={e => {setFiltros({...filtros, fechaInicio: e.target.value}); setPage(1);}} />
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Hasta</label>
          <input type="date" className="w-full px-3 py-2 rounded-xl border border-gray-200 text-sm outline-none focus:ring-2 focus:ring-navy-500" value={filtros.fechaFin} onChange={e => {setFiltros({...filtros, fechaFin: e.target.value}); setPage(1);}} />
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Rol</label>
          <select className="w-full px-3 py-2 rounded-xl border border-gray-200 text-sm outline-none focus:ring-2 focus:ring-navy-500" value={filtros.rol} onChange={e => {setFiltros({...filtros, rol: e.target.value}); setPage(1);}}>
            <option value="">Todos los roles</option>
            <option value="ADMIN">Administrador</option>
            <option value="GESTOR">Gestor</option>
            <option value="MAESTRA">Docente / Maestra</option>
          </select>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Acción</label>
          <select className="w-full px-3 py-2 rounded-xl border border-gray-200 text-sm outline-none focus:ring-2 focus:ring-navy-500" value={filtros.accion} onChange={e => {setFiltros({...filtros, accion: e.target.value}); setPage(1);}}>
            <option value="">Todas las acciones</option>
            <option value="INSERT">Crear</option>
            <option value="UPDATE">Actualizar</option>
            <option value="DELETE">Eliminar</option>
            <option value="LOGIN">Acceso (Login)</option>
          </select>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Usuario</label>
          <select className="w-full px-3 py-2 rounded-xl border border-gray-200 text-sm outline-none focus:ring-2 focus:ring-navy-500" value={filtros.usuarioId} onChange={e => {setFiltros({...filtros, usuarioId: e.target.value}); setPage(1);}}>
            <option value="">Todos los usuarios</option>
            {usuariosDisp.map(u => (
              <option key={u.usuarioId || u.id} value={u.usuarioId || u.id}>{u.nombreCompleto || u.nombre}</option>
            ))}
          </select>
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 flex flex-col overflow-hidden">
        <div className="flex-1 overflow-auto">
          <table className="w-full text-sm text-left relative">
            <thead className="bg-gray-50 text-gray-600 sticky top-0 z-10 shadow-sm border-b border-gray-100">
              <tr>
                <th className="p-4 font-semibold w-16">ID</th>
                <th className="p-4 font-semibold w-40">Fecha y Hora</th>
                <th className="p-4 font-semibold">Usuario</th>
                <th className="p-4 font-semibold">Rol</th>
                <th className="p-4 font-semibold">Acción</th>
                <th className="p-4 font-semibold">Entidad Afectada</th>
                <th className="p-4 font-semibold">Detalle</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading && logs.length === 0 ? (
                <tr><td colSpan={7} className="p-8 text-center text-navy-600 font-medium">Cargando registros...</td></tr>
              ) : logs.length === 0 ? (
                <tr>
                  <td colSpan={7} className="p-12 text-center text-gray-400">
                    <FileText className="w-12 h-12 mx-auto mb-3 text-gray-200" />
                    No hay registros de auditoría disponibles.
                  </td>
                </tr>
              ) : (
                logs.map(log => (
                  <tr key={log.logId} className="hover:bg-gray-50/80 transition-colors">
                    <td className="p-4 font-mono text-gray-400">#{log.logId}</td>
                    <td className="p-4 whitespace-nowrap text-gray-600">{new Date(log.fechaHora).toLocaleString('es-MX')}</td>
                    <td className="p-4 font-bold text-navy-800">{log.usuario}</td>
                    <td className="p-4 text-gray-500"><span className="bg-gray-100 px-2 py-1 rounded text-xs font-semibold">{log.rol}</span></td>
                    <td className={`p-4 font-bold ${getActionColor(log.tipoAccion)}`}>{log.tipoAccion}</td>
                    <td className="p-4 font-medium text-gray-700">{log.entidad}</td>
                    <td className="p-4 text-gray-500 text-xs max-w-xs truncate" title={log.detalle}>{log.detalle}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <div className="border-t border-gray-100 bg-gray-50 p-4 flex items-center justify-between">
            <span className="text-sm text-gray-500 font-medium">
              Página {page} de {totalPages} <span className="mx-2">•</span> {totalRecords} registros
            </span>
            <div className="flex gap-2">
              <button 
                disabled={page <= 1 || loading}
                onClick={() => setPage(page - 1)}
                className="px-4 py-1.5 text-sm font-medium text-navy-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50 transition-colors"
              >
                Anterior
              </button>
              <button 
                disabled={page >= totalPages || loading}
                onClick={() => setPage(page + 1)}
                className="px-4 py-1.5 text-sm font-medium text-navy-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50 transition-colors"
              >
                Siguiente
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
