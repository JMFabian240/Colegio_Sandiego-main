import React, { useState, useEffect } from 'react';
import { Star, Plus, Award, X, Search, ShieldAlert, CheckCircle2 } from 'lucide-react';
import { becasService } from '../services/becas.service';
import { alumnosService } from '../services/alumnos.service';
import { useAuthStore } from '../store/useAuthStore';

export function Becas() {
  const { user } = useAuthStore();
  const isAdmin = user?.rol === 'ADMIN' || user?.rol === 'DIRECTOR';

  const [catalogo, setCatalogo] = useState<any[]>([]);
  const [asignadas, setAsignadas] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);

  // Modal Nuevo Tipo Beca
  const [isModalTipoOpen, setIsModalTipoOpen] = useState(false);
  const [tipoForm, setTipoForm] = useState({ becaId: null, nombreBeca: '', criterio: '', porcentaje: '' });

  // Modal Asignar Beca
  const [isModalAsignarOpen, setIsModalAsignarOpen] = useState(false);
  const [asignarForm, setAsignarForm] = useState({ alumnoId: '', becaId: '', motivo: '' });
  const [busquedaAlumno, setBusquedaAlumno] = useState('');
  const [alumnosSugeridos, setAlumnosSugeridos] = useState<any[]>([]);

  useEffect(() => {
    cargarCatalogo();
    cargarAsignadas();

    const urlParams = new URLSearchParams(window.location.search);
    const alumnoId = urlParams.get('alumnoId');
    const alumnoNombre = urlParams.get('alumnoNombre');
    
    if (alumnoId) {
      setAsignarForm(prev => ({ ...prev, alumnoId }));
      setBusquedaAlumno(alumnoNombre || `ID: ${alumnoId}`);
      setIsModalAsignarOpen(true);
      window.history.replaceState({}, '', '/becas');
    }
  }, []);

  const cargarCatalogo = async () => {
    try {
      const res: any = await becasService.obtenerCatalogo();
      const data = res.data?.data || res.data || [];
      setCatalogo(Array.isArray(data) ? data : []);
    } catch (e) { console.warn(e); }
  };

  const cargarAsignadas = async () => {
    setLoading(true);
    try {
      const res: any = await becasService.obtenerAsignaciones();
      const data = res.data?.data || res.data || [];
      setAsignadas(Array.isArray(data) ? data : []);
    } catch (e) { console.warn(e); }
    finally { setLoading(false); }
  };

  const handleGuardarTipo = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const payload = {
        nombreBeca: tipoForm.nombreBeca,
        criterio: tipoForm.criterio,
        porcentaje: Number(tipoForm.porcentaje)
      };

      if (tipoForm.becaId) {
        await becasService.actualizarEnCatalogo(Number(tipoForm.becaId), payload);
      } else {
        await becasService.crearEnCatalogo(payload);
      }
      alert('Tipo de beca guardado exitosamente.');
      setIsModalTipoOpen(false);
      cargarCatalogo();
    } catch (error: any) {
      console.error('Error guardando tipo beca', error);
      alert(error.response?.data?.message || 'Error al guardar el tipo de beca.');
    } finally {
      setSaving(false);
    }
  };

  const openEditarTipo = (beca: any) => {
    setTipoForm({
      becaId: beca.becaId || beca.id,
      nombreBeca: beca.nombreBeca,
      criterio: beca.criterio,
      porcentaje: String(beca.porcentaje)
    });
    setIsModalTipoOpen(true);
  };

  // Buscar alumnos para asignar
  useEffect(() => {
    const timer = setTimeout(() => {
      if (busquedaAlumno.trim() && !asignarForm.alumnoId) {
        alumnosService.getAlumnos({ q: busquedaAlumno, limit: 10 })
          .then((res: any) => {
            const payload = res.data?.data || res.data || res;
            const arr = Array.isArray(payload) ? payload : (payload.alumnos || []);
            setAlumnosSugeridos(arr);
          })
          .catch(() => setAlumnosSugeridos([]));
      } else {
        setAlumnosSugeridos([]);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [busquedaAlumno, asignarForm.alumnoId]);

  const seleccionarAlumno = (al: any) => {
    setAsignarForm({ ...asignarForm, alumnoId: al.id });
    setBusquedaAlumno(`${al.nombre} (${al.matricula})`);
    setAlumnosSugeridos([]);
  };

  const handleAsignarBeca = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!asignarForm.alumnoId || !asignarForm.becaId) return alert('Selecciona alumno y beca.');
    
    setSaving(true);
    try {
      await becasService.asignar({
        alumnoId: Number(asignarForm.alumnoId),
        becaId: Number(asignarForm.becaId),
        cicloId: 1,
        observaciones: asignarForm.motivo
      });
      alert('Beca asignada exitosamente.');
      setIsModalAsignarOpen(false);
      cargarAsignadas();
    } catch (error: any) {
      console.error('Error asignando', error);
      alert(error.response?.data?.message || 'Error al asignar la beca.');
    } finally {
      setSaving(false);
    }
  };

  const retirarBeca = async (id: string | number) => {
    const motivo = prompt('Ingresa el motivo del retiro de la beca (Obligatorio):');
    if (!motivo) return;
    
    try {
      await becasService.retirar(Number(id), motivo);
      alert('Beca retirada exitosamente.');
      cargarAsignadas();
    } catch (error: any) {
      console.error('Error retirando', error);
      alert(error.response?.data?.message || 'Hubo un error al intentar retirar la beca.');
    }
  };

  const cambiarBeca = (asig: any) => {
    // asig.alumnoId or asig.alumno.id
    const alId = asig.alumno?.id || asig.alumnoId;
    const alNombre = asig.alumno?.nombre || asig.alumnoId;
    setAsignarForm({ alumnoId: String(alId), becaId: '', motivo: '' });
    setBusquedaAlumno(String(alNombre));
    setIsModalAsignarOpen(true);
  };

  const getCardStyle = (criterio: string) => {
    if (criterio === 'hermanos') return 'bg-emerald-50 text-emerald-600 border-emerald-100';
    if (criterio === 'calificacion') return 'bg-amber-50 text-amber-600 border-amber-100';
    return 'bg-navy-50 text-navy-600 border-navy-100';
  };

  const eliminarTipoBeca = async (becaId: number) => {
    if (!confirm('¿Estás seguro de que deseas eliminar este tipo de beca?')) return;
    try {
      await becasService.eliminarDeCatalogo(becaId);
      alert('Tipo de beca eliminado.');
      cargarCatalogo();
    } catch (error: any) {
      alert(error.response?.data?.message || 'Error al eliminar el tipo de beca.');
    }
  };

  return (
    <div className="h-full flex flex-col relative overflow-hidden">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-navy-800 flex items-center gap-2">
            <Award className="text-navy-600" /> Gestión de Becas
          </h2>
          <p className="text-sm text-gray-500 mt-1">Administra el catálogo de becas y asigna apoyos financieros a los alumnos.</p>
        </div>
        <div className="flex gap-3">
          {isAdmin && (
            <button 
              onClick={() => { setTipoForm({ becaId: null, nombreBeca: '', criterio: '', porcentaje: '' }); setIsModalTipoOpen(true); }}
              className="flex items-center gap-2 px-4 py-2 bg-white text-navy-700 border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors shadow-sm font-medium"
            >
              <Plus size={16} /> Registrar Tipo de Beca
            </button>
          )}
          <button 
            onClick={() => { setAsignarForm({ alumnoId: '', becaId: '', motivo: '' }); setBusquedaAlumno(''); setIsModalAsignarOpen(true); }}
            className="flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-xl hover:bg-emerald-700 transition-colors shadow-sm font-medium"
          >
            <Award size={16} /> Asignar Beca a Alumno
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-auto flex flex-col gap-6">
        {/* Catálogo de Becas */}
        {catalogo.length > 0 && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {catalogo.map(beca => (
              <div key={beca.becaId || beca.id} className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm text-center relative group transition-all hover:shadow-md">
                <div className={`w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-4 border ${getCardStyle(beca.criterio)}`}>
                  <Star className="w-7 h-7" />
                </div>
                <h3 className="font-bold text-gray-800 text-lg">{beca.nombreBeca}</h3>
                <div className={`text-4xl font-black mt-2 mb-1 ${getCardStyle(beca.criterio).split(' ')[1]}`}>
                  {beca.porcentaje}%
                </div>
                <p className="text-sm text-gray-500 capitalize">{beca.criterio}</p>
                
                {isAdmin && (
                  <div className="absolute top-4 right-4 opacity-0 group-hover:opacity-100 transition-opacity flex gap-2">
                    <button onClick={() => openEditarTipo(beca)} className="text-xs font-medium text-navy-600 hover:text-navy-800 bg-navy-50 px-3 py-1 rounded-full">Editar</button>
                    <button onClick={() => eliminarTipoBeca(beca.becaId || beca.id)} className="text-xs font-medium text-red-600 hover:text-red-800 bg-red-50 px-3 py-1 rounded-full">Eliminar</button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        {/* Tabla de Becas Asignadas */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 flex flex-col overflow-hidden min-h-[400px]">
          <div className="p-5 border-b border-gray-100 bg-gray-50/50">
            <h3 className="font-semibold text-gray-800">Becas Asignadas Actualmente</h3>
          </div>
          <div className="flex-1 overflow-auto">
            <table className="w-full text-sm text-left">
              <thead className="bg-gray-50 text-gray-600 sticky top-0">
                <tr>
                  <th className="p-4 font-semibold">Alumno</th>
                  <th className="p-4 font-semibold">Tipo de Beca</th>
                  <th className="p-4 font-semibold">Descuento</th>
                  <th className="p-4 font-semibold">Motivo</th>
                  <th className="p-4 font-semibold">Estado</th>
                  <th className="p-4 font-semibold text-right">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {loading && asignadas.length === 0 ? (
                  <tr><td colSpan={6} className="p-8 text-center text-gray-400">Cargando becas asignadas...</td></tr>
                ) : asignadas.length === 0 ? (
                  <tr><td colSpan={6} className="p-8 text-center text-gray-400">No hay becas asignadas en este momento.</td></tr>
                ) : (
                  asignadas.map(asig => (
                    <tr key={asig.id} className="hover:bg-gray-50/80 transition-colors">
                      <td className="p-4 font-bold text-navy-800">{asig.alumno?.nombre || asig.alumnoId}</td>
                      <td className="p-4 text-gray-600">{asig.nombre || asig.tipo}</td>
                      <td className="p-4">
                        <span className="font-black text-lg text-emerald-600">{asig.porcentaje}%</span>
                      </td>
                      <td className="p-4 text-gray-600 text-sm max-w-[200px]">
                        {asig.motivo ? (
                          <span className="italic">{asig.motivo}</span>
                        ) : (
                          <span className="text-gray-400">—</span>
                        )}
                      </td>
                      <td className="p-4">
                        {asig.activa ? (
                          <span className="flex items-center gap-1 text-xs font-bold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-md w-fit">
                            <CheckCircle2 size={14} /> Activa
                          </span>
                        ) : (
                          <span className="flex items-center gap-1 text-xs font-bold text-gray-500 bg-gray-100 px-2.5 py-1 rounded-md w-fit">
                            <ShieldAlert size={14} /> Inactiva
                          </span>
                        )}
                      </td>
                      <td className="p-4 text-right">
                        {asig.activa && isAdmin && (
                          <div className="flex justify-end gap-2">
                            <button 
                              onClick={() => cambiarBeca(asig)}
                              className="text-xs font-medium text-navy-600 hover:text-navy-800 hover:bg-navy-50 px-3 py-1.5 rounded-lg transition-colors"
                            >
                              Cambiar Beca
                            </button>
                            <button 
                              onClick={() => retirarBeca(asig.id)}
                              className="text-xs font-medium text-red-600 hover:text-red-800 hover:bg-red-50 px-3 py-1.5 rounded-lg transition-colors"
                            >
                              Retirar
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Modal Tipo Beca */}
      {isModalTipoOpen && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl w-full max-w-md shadow-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h3 className="text-lg font-bold text-navy-800">{tipoForm.becaId ? 'Editar' : 'Registrar'} Tipo de Beca</h3>
              <button onClick={() => setIsModalTipoOpen(false)} className="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-gray-100 transition-colors"><X size={20} /></button>
            </div>
            <form onSubmit={handleGuardarTipo} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nombre de la Beca</label>
                <input required type="text" className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none" value={tipoForm.nombreBeca} onChange={e => setTipoForm({...tipoForm, nombreBeca: e.target.value})} placeholder="Ej. Beca Excelencia" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Criterio / Categoría</label>
                <select required className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none" value={tipoForm.criterio} onChange={e => setTipoForm({...tipoForm, criterio: e.target.value})}>
                  <option value="">Seleccione un criterio</option>
                  <option value="calificacion">Por Calificación Promedio</option>
                  <option value="hermanos">Descuento de Hermanos</option>
                  <option value="deportiva">Beca Deportiva</option>
                  <option value="especial">Socioeconómica / Especial</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Porcentaje de Descuento (%)</label>
                <input required type="number" min="1" max="100" className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none" value={tipoForm.porcentaje} onChange={e => setTipoForm({...tipoForm, porcentaje: e.target.value})} placeholder="Ej. 15" />
              </div>
              <div className="pt-4 flex justify-end gap-3">
                <button type="button" onClick={() => setIsModalTipoOpen(false)} className="px-5 py-2.5 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors">Cancelar</button>
                <button type="submit" disabled={saving} className="px-5 py-2.5 text-sm font-medium text-white bg-navy-600 hover:bg-navy-700 rounded-xl transition-colors shadow-sm disabled:opacity-70">{saving ? 'Guardando...' : 'Guardar'}</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Asignar Beca */}
      {isModalAsignarOpen && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl w-full max-w-md shadow-2xl overflow-hidden overflow-y-visible">
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center bg-emerald-50/50">
              <h3 className="text-lg font-bold text-emerald-800">Asignar Beca a Alumno</h3>
              <button onClick={() => setIsModalAsignarOpen(false)} className="text-emerald-700 hover:text-emerald-900 p-2 rounded-full hover:bg-emerald-100 transition-colors"><X size={20} /></button>
            </div>
            <form onSubmit={handleAsignarBeca} className="p-6 space-y-4 overflow-visible">
              <div className="relative z-20">
                <label className="block text-sm font-medium text-gray-700 mb-1">Buscar Alumno</label>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                  <input 
                    type="text" 
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none" 
                    placeholder="Nombre o matrícula..."
                    value={busquedaAlumno}
                    onChange={e => { setBusquedaAlumno(e.target.value); setAsignarForm({...asignarForm, alumnoId: ''}); }}
                  />
                </div>
                {alumnosSugeridos.length > 0 && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-xl shadow-lg max-h-48 overflow-y-auto">
                    {alumnosSugeridos.map(al => (
                      <div key={al.id} onClick={() => seleccionarAlumno(al)} className="px-4 py-2 hover:bg-emerald-50 cursor-pointer border-b border-gray-50 last:border-0">
                        <div className="font-medium text-navy-800">{al.nombre}</div>
                        <div className="text-xs text-gray-500">{al.matricula}</div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
              <div className="relative z-10">
                <label className="block text-sm font-medium text-gray-700 mb-1">Seleccionar Tipo de Beca</label>
                <select required className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none" value={asignarForm.becaId} onChange={e => setAsignarForm({...asignarForm, becaId: e.target.value})}>
                  <option value="">Seleccione una beca del catálogo</option>
                  {catalogo.map(b => <option key={b.becaId || b.id} value={b.becaId || b.id}>{b.nombreBeca} ({b.porcentaje}%)</option>)}
                </select>
              </div>
              <div className="relative z-0">
                <label className="block text-sm font-medium text-gray-700 mb-1">Motivo / Observaciones (Opcional)</label>
                <textarea className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-emerald-500 outline-none resize-none h-20" value={asignarForm.motivo} onChange={e => setAsignarForm({...asignarForm, motivo: e.target.value})} placeholder="Ej. Promedio de 9.8 en el ciclo anterior." />
              </div>
              <div className="pt-4 flex justify-end gap-3 relative z-0">
                <button type="button" onClick={() => setIsModalAsignarOpen(false)} className="px-5 py-2.5 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors">Cancelar</button>
                <button type="submit" disabled={saving || !asignarForm.alumnoId} className="px-5 py-2.5 text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl transition-colors shadow-sm disabled:opacity-70">{saving ? 'Asignando...' : 'Asignar Beca'}</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
