import React, { useState, useEffect } from 'react';
import { CreditCard, Plus, Search, DollarSign, X, CheckCircle2, Printer } from 'lucide-react';
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
    metodoPago: 'transferencia',
    fecha: new Date().toISOString().split('T')[0]
  });
  const [comprobante, setComprobante] = useState<File | null>(null);
  const [pagoAdelantado, setPagoAdelantado] = useState(false);
  const [mesesAdelanto, setMesesAdelanto] = useState('1');
  
  const [saving, setSaving] = useState(false);
  const [ticketRecibo, setTicketRecibo] = useState<any>(null);

  const imprimirTicket = () => {
    const contenido = document.getElementById('ticket-imprimible')?.innerHTML;
    if (!contenido) return;
    const ventanaImpresion = window.open('', '', 'height=600,width=400');
    if (ventanaImpresion) {
      ventanaImpresion.document.write('<html><head><title>Imprimir Recibo</title>');
      ventanaImpresion.document.write('<style>');
      ventanaImpresion.document.write('body { font-family: sans-serif; padding: 20px; }');
      ventanaImpresion.document.write('.text-center { text-align: center; }');
      ventanaImpresion.document.write('.mb-6 { margin-bottom: 24px; }');
      ventanaImpresion.document.write('.font-bold { font-weight: bold; }');
      ventanaImpresion.document.write('.text-lg { font-size: 18px; }');
      ventanaImpresion.document.write('.text-sm { font-size: 14px; }');
      ventanaImpresion.document.write('.text-gray-500 { color: #6b7280; }');
      ventanaImpresion.document.write('.text-gray-700 { color: #374151; }');
      ventanaImpresion.document.write('.text-gray-800 { color: #1f2937; }');
      ventanaImpresion.document.write('.text-navy-900 { color: #0f172a; }');
      ventanaImpresion.document.write('.flex { display: flex; }');
      ventanaImpresion.document.write('.justify-between { justify-content: space-between; }');
      ventanaImpresion.document.write('.items-center { align-items: center; }');
      ventanaImpresion.document.write('.border-t { border-top: 1px solid #f3f4f6; }');
      ventanaImpresion.document.write('.my-3 { margin-top: 12px; margin-bottom: 12px; }');
      ventanaImpresion.document.write('.pt-3 { padding-top: 12px; }');
      ventanaImpresion.document.write('.space-y-3 > div { margin-bottom: 12px; }');
      ventanaImpresion.document.write('</style>');
      ventanaImpresion.document.write('</head><body>');
      ventanaImpresion.document.write(contenido);
      ventanaImpresion.document.write('</body></html>');
      ventanaImpresion.document.close();
      ventanaImpresion.focus();
      setTimeout(() => {
        ventanaImpresion.print();
        ventanaImpresion.close();
      }, 250);
    }
  };

  useEffect(() => {
    cargarPagos(page);
    
    // Check if came from Alumnos profile
    const urlParams = new URLSearchParams(window.location.search);
    const alId = urlParams.get('alumnoId');
    if (alId) {
      setIsModalOpen(true);
      api.get(`/alumnos/${alId}`).then(res => {
        if (res.data) {
          seleccionarAlumno(res.data);
        }
      }).catch(console.error);
    }
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
    setBusquedaAlumno(`${al.nombre || al.nombreCompleto} (${al.matricula})`);
    setAlumnosSugeridos([]);
    setCalculando(true);
    
    const id = al.id || al.alumnoId;
    try {
      let becaInfo = null;
      // Obtener ficha completa para ver si tiene beca
      const alRes = await api.get(`/alumnos/${id}`);
      if (alRes.data && alRes.data.beca) {
        becaInfo = alRes.data.beca;
      }
      
      // Obtener adeudos
      const adRes = await api.get('/pagos/calendario', { params: { alumnoId: id, estadoCobro: 'pendiente' } });
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
          concepto: primerConcepto
        }));
        recalcularMontoPorConcepto(primerConcepto, adRes.data, becaInfo ? Number(becaInfo.porcentaje) : 0);
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
    setPagoForm({ concepto: 'Colegiatura', monto: '', metodoPago: 'transferencia', fecha: new Date().toISOString().split('T')[0] });
    setComprobante(null);
    setPagoAdelantado(false);
    setMesesAdelanto('1');
    setTicketRecibo(null);
  };

  const recalcularMontoPorConcepto = (conceptoBuscado: string, deudas: any[], porcBeca: number) => {
    let total = 0;
    const key = conceptoBuscado.toLowerCase().replace(/_/, ' ');
    const adeudosFiltrados = deudas.filter((d: any) => {
      const c = (d.concepto || '').toLowerCase().replace(/_/, ' ');
      return c.includes(key) || key.includes(c);
    });

    if (adeudosFiltrados.length > 0) {
      adeudosFiltrados.forEach((d: any) => {
        let deuda = Number(d.montoOriginal) + Number(d.montoRecargo || 0) - Number(d.montoPagado || 0);
        if (d.concepto?.toLowerCase() === 'colegiatura') {
          deuda -= (deuda * porcBeca) / 100;
        }
        total += Math.max(0, deuda);
      });
    } else {
      // Si no hay deudas del concepto, el total es 0 (el usuario lo pone manual)
      total = 0; 
    }
    setPagoForm(prev => ({ ...prev, monto: total > 0 ? total.toFixed(2) : '' }));
  };

  const recalcularMontoAdelanto = async (meses: number) => {
    if (!alumnoSeleccionado) return;
    const id = alumnoSeleccionado.id || alumnoSeleccionado.alumnoId;
    try {
      const becaRes = await api.get(`/alumnos/${id}`);
      const asignacion = becaRes.data?.asignacionesBeca?.find((b: any) => b.estado === 'activa');
      const porcBeca = asignacion?.beca?.porcentaje || 0;
      
      const deudasFiltradas = adeudos.filter((d:any) => d.concepto?.toLowerCase() === 'colegiatura');
      const periodos = deudasFiltradas.slice(0, meses);
      
      let total = 0;
      periodos.forEach((d: any) => {
        let deuda = Number(d.montoOriginal) + Number(d.montoRecargo || 0) - Number(d.montoPagado || 0);
        deuda -= (deuda * Number(porcBeca)) / 100;
        total += Math.max(0, deuda);
      });
      setPagoForm(prev => ({ ...prev, monto: total.toFixed(2) }));
    } catch(e) {}
  };

  const registrarPago = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!alumnoSeleccionado) return alert('Seleccione un alumno.');
    if (!pagoForm.monto || Number(pagoForm.monto) <= 0) return alert('Ingrese un monto válido.');

    setSaving(true);
    const id = alumnoSeleccionado.id || alumnoSeleccionado.alumnoId;
    try {
      const conceptoBackendMap: Record<string, string> = {
        'Colegiatura': 'COLEGIATURA',
        'Inscripcion': 'INSCRIPCION',
        'Inscripción': 'INSCRIPCION',
        'Material_didactico': 'MATERIAL_DIDACTICO',
        'Material didáctico': 'MATERIAL_DIDACTICO',
        'Uniforme': 'UNIFORME',
        'Otro': 'OTRO'
      };
      const conceptoToSend = conceptoBackendMap[pagoForm.concepto] || 'COLEGIATURA';

      let res;
      if (pagoAdelantado && conceptoToSend === 'COLEGIATURA') {
        res = await api.post('/pagos/adelantado', {
          alumnoId: id,
          monto: Number(pagoForm.monto),
          meses: Number(mesesAdelanto),
          metodoPago: pagoForm.metodoPago,
          fecha: pagoForm.fecha
        });
      } else {
        res = await api.post('/pagos', {
          alumnoId: id,
          monto: Number(pagoForm.monto),
          concepto: conceptoToSend,
          metodoPago: pagoForm.metodoPago,
          fecha: pagoForm.fecha
        });
      }

      // Subir comprobante si existe
      if (comprobante && res?.data?.data?.pagoId) {
        const formData = new FormData();
        formData.append('comprobante', comprobante);
        try {
          await api.post(`/pagos/${res.data.data.pagoId}/comprobante`, formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
          });
        } catch (uploadError) {
          console.error('Error subiendo comprobante', uploadError);
          alert('El pago se registró pero hubo un problema al subir el comprobante.');
        }
      }

      const pagoData = res?.data?.data || res?.data;
      setTicketRecibo({
        pagoId: pagoData?.pagoId || pagoData?.id || '---',
        fecha: new Date().toLocaleString('es-MX'),
        alumno: alumnoSeleccionado.nombre,
        concepto: pagoForm.concepto,
        monto: pagoForm.monto
      });
      cargarPagos(1);
    } catch (error: any) {
      console.error('Error registrando pago', error);
      alert(error.response?.data?.message || 'Error al registrar el pago.');
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
        <div className="flex gap-4">
          {isAdmin && (
            <button className="flex items-center gap-2 bg-navy-600 text-white px-5 py-2.5 rounded-xl hover:bg-navy-700 transition-colors shadow-sm font-medium" onClick={() => { setIsModalOpen(true); setTicketRecibo(null); limpiarSeleccion(); }}>
              <Plus size={20} />
              Nuevo Pago
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
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none pr-10" 
                    placeholder="Buscar alumno..."
                    value={busquedaAlumno}
                    onChange={e => { setBusquedaAlumno(e.target.value); if(alumnoSeleccionado) setAlumnoSeleccionado(null); }}
                  />
                  {alumnoSeleccionado && (
                    <button type="button" onClick={limpiarSeleccion} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-red-500">
                      <X size={16} />
                    </button>
                  )}
                </div>
                {alumnoSeleccionado && (
                  <div className="flex items-center gap-1 text-xs font-medium text-emerald-600 mt-2 px-1">
                    <CheckCircle2 size={14} /> Alumno seleccionado: {alumnoSeleccionado.nombre}
                  </div>
                )}
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
              ) : alumnoSeleccionado && !ticketRecibo && (
                <div className="space-y-4 animate-in fade-in slide-in-from-bottom-2 duration-300">
                  <div className="bg-gray-50 rounded-xl p-4 border border-gray-100 max-h-48 overflow-y-auto">
                    <h4 className="text-xs font-semibold text-gray-500 mb-3">Adeudos Pendientes</h4>
                    {adeudos.length === 0 ? (
                      <p className="text-sm text-gray-500">No hay adeudos pendientes.</p>
                    ) : (
                      <div className="space-y-2">
                        {adeudos.map((adeudo: any, idx: number) => {
                          const monto = Number(adeudo.montoOriginal) + Number(adeudo.montoRecargo || 0) - Number(adeudo.montoPagado || 0);
                          return (
                            <div key={idx} className="flex justify-between items-center bg-white p-3 rounded-lg border border-gray-200 shadow-sm">
                              <div>
                                <div className="font-medium text-sm text-gray-800 capitalize">{adeudo.concepto.replace(/_/g, ' ')} {adeudo.mes ? `(${adeudo.mes})` : ''}</div>
                                <div className="text-xs text-gray-400 mt-0.5">Vencimiento: {new Date(adeudo.fechaVencimiento).toLocaleDateString('es-MX')}</div>
                              </div>
                              <div className="font-bold text-red-600 text-sm">
                                ${monto.toFixed(2)}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>

                  <div className="flex bg-white rounded-xl border border-gray-200 p-1">
                    <button type="button" className={`flex-1 py-2 text-sm font-medium rounded-lg transition-colors ${!pagoAdelantado ? 'bg-navy-900 text-white shadow-sm' : 'text-gray-600 hover:bg-gray-50'}`} onClick={() => {
                      setPagoAdelantado(false);
                      recalcularMontoPorConcepto(pagoForm.concepto, adeudos, 0); 
                    }}>
                      Pago Normal
                    </button>
                    <button type="button" className={`flex-1 py-2 text-sm font-medium rounded-lg transition-colors ${pagoAdelantado ? 'bg-navy-900 text-white shadow-sm' : 'text-gray-600 hover:bg-gray-50'}`} onClick={() => {
                      setPagoAdelantado(true);
                      setPagoForm(prev => ({ ...prev, concepto: 'Colegiatura' }));
                      recalcularMontoAdelanto(Number(mesesAdelanto));
                    }}>
                      Pago Adelantado
                    </button>
                  </div>

                  {pagoAdelantado && (
                    <div className="flex items-center gap-3 bg-indigo-50/50 border border-indigo-100 rounded-xl p-3">
                      <span className="text-sm font-medium text-indigo-900">Adelantar</span>
                      <input type="number" min="1" max="12" className="w-20 px-3 py-1.5 rounded-lg border border-indigo-200 text-sm focus:ring-2 focus:ring-indigo-500 outline-none" value={mesesAdelanto} onChange={e => {
                        setMesesAdelanto(e.target.value);
                        recalcularMontoAdelanto(Number(e.target.value));
                      }} />
                      <span className="text-sm font-medium text-indigo-900">meses</span>
                    </div>
                  )}

                  <div className="grid grid-cols-1 gap-4">
                    <div>
                      <label className="block text-xs font-medium text-gray-700 mb-1">Concepto</label>
                      <select required disabled={pagoAdelantado} className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none disabled:bg-gray-100 disabled:cursor-not-allowed" value={pagoForm.concepto} onChange={e => {
                        const val = e.target.value;
                        setPagoForm({...pagoForm, concepto: val});
                        // Obtener beca % (simplificado a buscar la activa)
                        api.get(`/alumnos/${alumnoSeleccionado.id}`).then(res => {
                          const asig = res.data?.asignacionesBeca?.find((b:any)=>b.estado==='activa');
                          recalcularMontoPorConcepto(val, adeudos, asig?.beca?.porcentaje || 0);
                        });
                      }}>
                        <option value="Colegiatura">Colegiatura</option>
                        <option value="Inscripcion">Inscripción</option>
                        <option value="Material_didactico">Material Didáctico</option>
                        <option value="Uniforme">Uniforme</option>
                        <option value="Otro">Otro</option>
                      </select>
                    </div>
                  </div>

                  <div className="relative z-0">
                    <label className="block text-xs font-medium text-gray-700 mb-1">Monto</label>
                    <div className="relative">
                      <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                      <input 
                        required 
                        type="number" 
                        min="1" 
                        step="0.01"
                        className="w-full pl-9 pr-4 py-2.5 rounded-xl border border-gray-200 text-gray-800 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" 
                        value={pagoForm.monto} 
                        onChange={e => setPagoForm({...pagoForm, monto: e.target.value})}
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4 relative z-0">
                    <div>
                      <label className="block text-xs font-medium text-gray-700 mb-1">Fecha</label>
                      <input 
                        type="date"
                        required
                        className="w-full px-4 py-2.5 rounded-xl border border-gray-200 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                        value={pagoForm.fecha}
                        onChange={e => setPagoForm({...pagoForm, fecha: e.target.value})}
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-700 mb-1">Método de pago</label>
                      <select required className="w-full px-4 py-2.5 rounded-xl border border-gray-200 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" value={pagoForm.metodoPago} onChange={e => setPagoForm({...pagoForm, metodoPago: e.target.value})}>
                        <option value="transferencia">Transferencia</option>
                        <option value="efectivo">Efectivo</option>
                        <option value="tarjeta">Tarjeta (Crédito/Débito)</option>
                        <option value="cheque">Cheque</option>
                      </select>
                    </div>
                  </div>
                  
                  <div className="relative z-0">
                    <label className="block text-xs font-medium text-gray-700 mb-1 flex items-center gap-1"><span className="text-gray-400">📎</span> Adjuntar comprobante (Opcional)</label>
                    <input 
                      type="file" 
                      accept=".pdf,image/*"
                      className="w-full px-3 py-2 rounded-xl border border-gray-200 text-sm file:mr-4 file:py-1 file:px-3 file:rounded-lg file:border file:border-gray-300 file:text-xs file:font-medium file:bg-gray-100 file:text-gray-700 hover:file:bg-gray-200 cursor-pointer"
                      onChange={e => {
                        if(e.target.files && e.target.files.length > 0) {
                          setComprobante(e.target.files[0]);
                        } else {
                          setComprobante(null);
                        }
                      }}
                    />
                  </div>
                </div>
              )}

              {ticketRecibo ? (
                <div className="pt-4 border-t border-gray-100 mt-2 animate-in slide-in-from-bottom-4 fade-in duration-300">
                  <div id="ticket-imprimible" className="border-2 border-dashed border-gray-200 rounded-xl p-6 bg-white mb-6">
                    <div className="text-center mb-6">
                      <h4 className="font-bold text-lg text-navy-900 tracking-tight">COLEGIO SAN DIEGO</h4>
                      <p className="text-sm text-gray-500">Recibo de Pago No. {ticketRecibo.pagoId}</p>
                    </div>
                    <div className="space-y-3 text-sm">
                      <div className="flex justify-between">
                        <span className="text-gray-500 font-medium">Fecha:</span>
                        <span className="text-gray-800">{ticketRecibo.fecha}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500 font-medium">Alumno:</span>
                        <span className="text-gray-800 text-right max-w-[220px]">{ticketRecibo.alumno}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500 font-medium">Concepto:</span>
                        <span className="text-gray-800">{ticketRecibo.concepto}</span>
                      </div>
                      <div className="border-t border-gray-100 my-3 pt-3 flex justify-between items-center">
                        <span className="text-gray-700 font-bold">Total Pagado:</span>
                        <span className="text-lg font-bold text-navy-900">${Number(ticketRecibo.monto).toFixed(2)}</span>
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex justify-center gap-3">
                    <button type="button" onClick={() => setIsModalOpen(false)} className="px-5 py-2.5 text-sm font-medium text-gray-600 bg-white border border-gray-200 hover:bg-gray-50 rounded-xl transition-colors">Cerrar</button>
                    <button type="button" onClick={imprimirTicket} className="flex items-center gap-2 px-6 py-2.5 text-sm font-medium text-white bg-navy-800 hover:bg-navy-900 rounded-xl transition-colors shadow-sm">
                      <Printer size={16} /> Imprimir Recibo
                    </button>
                  </div>
                </div>
              ) : (
                <div className="pt-4 flex justify-end gap-3 border-t border-gray-100 relative z-0">
                  <button type="button" onClick={() => setIsModalOpen(false)} className="px-5 py-2.5 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors">Cancelar</button>
                  <button type="submit" disabled={saving || !alumnoSeleccionado} className="flex items-center gap-2 px-6 py-2.5 text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl transition-colors shadow-sm disabled:opacity-70">
                    <CheckCircle2 size={16} /> {saving ? 'Registrando...' : 'Registrar Pago'}
                  </button>
                </div>
              )}
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
