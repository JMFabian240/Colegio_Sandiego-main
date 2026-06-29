import React, { useState, useEffect } from 'react';
import { CreditCard, Plus, Search, DollarSign, X, CheckCircle2 } from 'lucide-react';
import api from '../services/api';
import { useAuthStore } from '../store/useAuthStore';

export function Pagos() {
  const { user } = useAuthStore();
  const isAdmin = user?.rol === 'ADMIN' || user?.rol === 'DIRECTOR' || user?.rol === 'GESTOR';

  const [pagos, setPagos] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalRecords, setTotalRecords] = useState(0);
  const limit = 20;

  // Modal Nuevo Pago
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [busquedaAlumno, setBusquedaAlumno] = useState('');
  const [alumnosSugeridos, setAlumnosSugeridos] = useState<any[]>([]);
  const [alumnoSeleccionado, setAlumnoSeleccionado] = useState<any>(null);
  
  const [adeudos, setAdeudos] = useState<any[]>([]);
  const [calculando, setCalculando] = useState(false);
  
  const [pagoForm, setPagoForm] = useState({
    concepto: 'Colegiatura',
    monto: '',
    metodoPago: 'transferencia'
  });
  
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    cargarPagos(page);
  }, [page]);

  const cargarPagos = async (pagina = 1) => {
    setLoading(true);
    try {
      const res = await api.get('/pagos', { params: { page: pagina, limit } });
      const data = res.data;
      if (data && data.data) {
        setPagos(data.data);
        setPage(data.pagination?.page || 1);
        setTotalPages(data.pagination?.pages || 1);
        setTotalRecords(data.pagination?.total || 0);
      } else if (Array.isArray(data)) {
        setPagos(data);
      }
    } catch (e) {
      console.warn('Error cargando pagos', e);
    } finally {
      setLoading(false);
    }
  };

  // Autocomplete Alumno
  useEffect(() => {
    const timer = setTimeout(() => {
      if (busquedaAlumno.trim() && !alumnoSeleccionado) {
        api.get('/alumnos', { params: { q: busquedaAlumno, limit: 10 } })
          .then(res => {
            const data = res.data.data || res.data;
            setAlumnosSugeridos(Array.isArray(data) ? data : []);
          })
          .catch(() => setAlumnosSugeridos([]));
      } else {
        setAlumnosSugeridos([]);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [busquedaAlumno, alumnoSeleccionado]);

  const seleccionarAlumno = async (al: any) => {
    setAlumnoSeleccionado(al);
    setBusquedaAlumno(`${al.nombre} (${al.matricula})`);
    setAlumnosSugeridos([]);
    setCalculando(true);
    
    try {
      let becaInfo = null;
      // Obtener ficha completa para ver si tiene beca
      const alRes = await api.get(`/alumnos/${al.id}`);
      if (alRes.data && alRes.data.beca) {
        becaInfo = alRes.data.beca;
      }
      
      // Obtener adeudos
      const adRes = await api.get('/pagos/calendario', { params: { alumnoId: al.id, estadoCobro: 'pendiente' } });
      if (adRes.data) {
        setAdeudos(adRes.data);
        
        // Calcular monto sugerido del primer adeudo
        let total = 0;
        let primerConcepto = 'Colegiatura';
        
        if (adRes.data.length > 0) {
          adRes.data.forEach((d: any) => {
            let deuda = Number(d.montoOriginal) + Number(d.montoRecargo || 0) - Number(d.montoPagado || 0);
            if (d.concepto?.toLowerCase() === 'colegiatura' && becaInfo) {
              deuda -= (deuda * Number(becaInfo.porcentaje)) / 100;
            }
            total += Math.max(0, deuda);
          });
          
          const primer = adRes.data[0];
          const cMap: Record<string, string> = { 'COLEGIATURA': 'Colegiatura', 'INSCRIPCION': 'Inscripción', 'MATERIAL_DIDACTICO': 'Material didáctico', 'UNIFORME': 'Uniforme' };
          primerConcepto = cMap[primer.concepto?.toUpperCase()] || 'Colegiatura';
        }
        
        setPagoForm(prev => ({
          ...prev,
          concepto: primerConcepto,
          monto: total.toFixed(2)
        }));
      }
    } catch (e) {
      console.error('Error calculando adeudos', e);
    } finally {
      setCalculando(false);
    }
  };

  const limpiarSeleccion = () => {
    setAlumnoSeleccionado(null);
    setBusquedaAlumno('');
    setAdeudos([]);
    setPagoForm({ concepto: 'Colegiatura', monto: '', metodoPago: 'transferencia' });
  };

  const registrarPago = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!alumnoSeleccionado) return alert('Seleccione un alumno.');
    if (!pagoForm.monto || Number(pagoForm.monto) <= 0) return alert('Ingrese un monto válido.');

    setSaving(true);
    try {
      await api.post('/pagos', {
        alumnoId: alumnoSeleccionado.id,
        monto: Number(pagoForm.monto),
        concepto: pagoForm.concepto,
        metodoPago: pagoForm.metodoPago,
        fecha: new Date().toISOString().split('T')[0]
      });
      alert('Pago registrado correctamente.');
      setIsModalOpen(false);
      cargarPagos(1);
    } catch (error) {
      console.error('Error registrando pago', error);
      alert('Error al registrar el pago.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="h-full flex flex-col relative overflow-hidden">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-navy-800 flex items-center gap-2">
            <CreditCard className="text-navy-600" /> Registro de Pagos
          </h2>
          <p className="text-sm text-gray-500 mt-1">Consulta el historial de pagos y registra nuevas transacciones.</p>
        </div>
        <div className="flex gap-3">
          {isAdmin && (
            <button 
              onClick={() => { limpiarSeleccion(); setIsModalOpen(true); }}
              className="flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-xl hover:bg-emerald-700 transition-colors shadow-sm font-medium"
            >
              <Plus size={16} /> Nuevo Pago
            </button>
          )}
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 flex flex-col overflow-hidden">
        <div className="flex-1 overflow-auto">
          <table className="w-full text-sm text-left">
            <thead className="bg-gray-50 text-gray-600 sticky top-0 shadow-sm border-b border-gray-100">
              <tr>
                <th className="p-4 font-semibold w-20">ID</th>
                <th className="p-4 font-semibold">Alumno</th>
                <th className="p-4 font-semibold">Concepto</th>
                <th className="p-4 font-semibold">Fecha</th>
                <th className="p-4 font-semibold text-right">Monto</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading && pagos.length === 0 ? (
                <tr><td colSpan={5} className="p-8 text-center text-gray-400">Cargando pagos...</td></tr>
              ) : pagos.length === 0 ? (
                <tr><td colSpan={5} className="p-8 text-center text-gray-400">No hay pagos registrados.</td></tr>
              ) : (
                pagos.map((p, i) => (
                  <tr key={p.id || i} className="hover:bg-gray-50/80 transition-colors">
                    <td className="p-4 font-mono text-gray-400">#{p.pagoId || p.id}</td>
                    <td className="p-4 font-bold text-navy-800">{p.alumno?.nombre || 'Desconocido'}</td>
                    <td className="p-4 text-gray-600 capitalize">{p.concepto?.replace(/_/g, ' ')}</td>
                    <td className="p-4 text-gray-500">{new Date(p.fecha).toLocaleDateString('es-MX')}</td>
                    <td className="p-4 text-right font-mono font-bold text-emerald-600">
                      ${Number(p.monto).toLocaleString('es-MX', {minimumFractionDigits: 2})}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <div className="border-t border-gray-100 bg-gray-50 p-4 flex items-center justify-between">
            <span className="text-sm text-gray-500 font-medium">
              Página {page} de {totalPages} <span className="mx-2">•</span> {totalRecords} pagos
            </span>
            <div className="flex gap-2">
              <button disabled={page <= 1 || loading} onClick={() => setPage(page - 1)} className="px-4 py-1.5 text-sm font-medium text-navy-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50">Anterior</button>
              <button disabled={page >= totalPages || loading} onClick={() => setPage(page + 1)} className="px-4 py-1.5 text-sm font-medium text-navy-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50">Siguiente</button>
            </div>
          </div>
        )}
      </div>

      {/* Modal Nuevo Pago */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden overflow-y-visible">
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center bg-emerald-50/50">
              <h3 className="text-lg font-bold text-emerald-800 flex items-center gap-2"><DollarSign size={20} /> Registrar Nuevo Pago</h3>
              <button onClick={() => setIsModalOpen(false)} className="text-emerald-700 hover:text-emerald-900 p-2 rounded-full hover:bg-emerald-100 transition-colors"><X size={20} /></button>
            </div>
            
            <form onSubmit={registrarPago} className="p-6 space-y-5 overflow-visible">
              <div className="relative z-20">
                <label className="block text-sm font-medium text-gray-700 mb-1">Buscar Alumno</label>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                  <input 
                    type="text" 
                    className="w-full pl-10 pr-10 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none" 
                    placeholder="Escribe el nombre o matrícula..."
                    value={busquedaAlumno}
                    onChange={e => { setBusquedaAlumno(e.target.value); if(alumnoSeleccionado) setAlumnoSeleccionado(null); }}
                  />
                  {alumnoSeleccionado && (
                    <button type="button" onClick={limpiarSeleccion} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-red-500">
                      <X size={16} />
                    </button>
                  )}
                </div>
                {alumnosSugeridos.length > 0 && !alumnoSeleccionado && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-xl shadow-lg max-h-48 overflow-y-auto">
                    {alumnosSugeridos.map(al => (
                      <div key={al.id} onClick={() => seleccionarAlumno(al)} className="px-4 py-2 hover:bg-emerald-50 cursor-pointer border-b border-gray-50 last:border-0 flex justify-between items-center">
                        <div>
                          <div className="font-medium text-navy-800">{al.nombre}</div>
                          <div className="text-xs text-gray-500 font-mono">{al.matricula}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {calculando ? (
                <div className="text-center py-4 text-emerald-600 font-medium animate-pulse">Calculando adeudos...</div>
              ) : alumnoSeleccionado && (
                <div className="space-y-4 animate-in fade-in slide-in-from-bottom-2 duration-300">
                  <div className="bg-gray-50 p-4 rounded-xl border border-gray-100 flex gap-4 items-center">
                    <div className="w-12 h-12 bg-white rounded-full border border-gray-200 flex items-center justify-center font-bold text-gray-400 text-lg">
                      {alumnoSeleccionado.nombre.charAt(0)}
                    </div>
                    <div>
                      <div className="font-bold text-navy-800">{alumnoSeleccionado.nombre}</div>
                      <div className="text-sm text-gray-500 font-mono">{alumnoSeleccionado.matricula}</div>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4 relative z-0">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Concepto</label>
                      <select required className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none" value={pagoForm.concepto} onChange={e => setPagoForm({...pagoForm, concepto: e.target.value})}>
                        <option value="Colegiatura">Colegiatura</option>
                        <option value="Inscripcion">Inscripción</option>
                        <option value="Material_didactico">Material Didáctico</option>
                        <option value="Uniforme">Uniforme</option>
                        <option value="Otro">Otro</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Método de Pago</label>
                      <select required className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none" value={pagoForm.metodoPago} onChange={e => setPagoForm({...pagoForm, metodoPago: e.target.value})}>
                        <option value="transferencia">Transferencia</option>
                        <option value="efectivo">Efectivo</option>
                        <option value="tarjeta">Tarjeta (Terminal)</option>
                      </select>
                    </div>
                  </div>

                  <div className="relative z-0">
                    <label className="block text-sm font-medium text-gray-700 mb-1">Monto a Cobrar ($)</label>
                    <div className="relative">
                      <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                      <input 
                        required 
                        type="number" 
                        min="1" 
                        step="0.01"
                        className="w-full pl-10 pr-4 py-3 rounded-xl border border-emerald-200 bg-emerald-50/30 text-emerald-800 font-bold text-lg focus:ring-2 focus:ring-emerald-500 outline-none" 
                        value={pagoForm.monto} 
                        onChange={e => setPagoForm({...pagoForm, monto: e.target.value})}
                      />
                    </div>
                    {adeudos.length > 0 && (
                      <p className="text-xs text-gray-500 mt-1">El monto sugerido se calculó en base a los adeudos pendientes.</p>
                    )}
                  </div>
                </div>
              )}

              <div className="pt-4 flex justify-end gap-3 border-t border-gray-100 relative z-0">
                <button type="button" onClick={() => setIsModalOpen(false)} className="px-5 py-2.5 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors">Cancelar</button>
                <button type="submit" disabled={saving || !alumnoSeleccionado} className="flex items-center gap-2 px-6 py-2.5 text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl transition-colors shadow-sm disabled:opacity-70">
                  <CheckCircle2 size={16} /> {saving ? 'Registrando...' : 'Registrar Pago'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
