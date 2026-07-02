import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Calendar, CreditCard, Clock, FileText, ChevronRight, CheckCircle2, Search, UserPlus, Phone, Mail, MapPin, Briefcase, Plus, X, GraduationCap, Edit, Trash2, Upload, Download, Award, Users, Receipt, ArrowLeft, Paperclip, Loader2 } from 'lucide-react';
import { alumnosService } from '../services/alumnos.service';
import { tutoresService } from '../services/tutores.service';
import { pagosService } from '../services/pagos.service';
import { gruposService } from '../services/grupos.service';
import { calificacionesService } from '../services/calificaciones.service';
import type { Alumno, Tutor } from '../types';

export function AlumnoPerfil() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [loading, setLoading] = useState(true);
  const [alumnoSeleccionado, setAlumnoSeleccionado] = useState<any>(null);
  const [alumnoFichaEditable, setAlumnoFichaEditable] = useState<any>({});
  
  const [tabAlumnoFicha, setTabAlumnoFicha] = useState('academicos');
  const [gruposData, setGruposData] = useState<any[]>([]);
  
  const [padresAlumno, setPadresAlumno] = useState<any[]>([]);
  const [estadoCuentaAlumno, setEstadoCuentaAlumno] = useState<any[]>([]);
  const [historialPagosAlumno, setHistorialPagosAlumno] = useState<any[]>([]);
  const [calificacionesAlumno, setCalificacionesAlumno] = useState<any[]>([]);
  const [calificacionesExtra, setCalificacionesExtra] = useState<any[]>([]);
  
  const [planPreview, setPlanPreview] = useState<any>(null);
  const [mesesPlanSeleccionado, setMesesPlanSeleccionado] = useState<number | null>(null);
  const [loadingPlan, setLoadingPlan] = useState(false);

  const [modalVincularTutor, setModalVincularTutor] = useState(false);
  const [busquedaVincularTutor, setBusquedaVincularTutor] = useState('');
  const [tutoresParaVincular, setTutoresParaVincular] = useState<Tutor[]>([]);
  const [uploadingPagoId, setUploadingPagoId] = useState<number | null>(null);

  const nivelesDisponibles = ['PREESCOLAR', 'PRIMARIA', 'SECUNDARIA', 'BACHILLERATO'];

  useEffect(() => {
    cargarGrupos();
    cargarFichaAlumno();
  }, [id]);

  const cargarGrupos = async () => {
    try {
      const res: any = await gruposService.obtenerTodos({ limit: 1000, todos: true });
      setGruposData(res.data?.data || res.data || []);
    } catch (error) {
      console.error('Error cargando grupos', error);
    }
  };

  const cargarFichaAlumno = async () => {
    if (!id) return;
    setLoading(true);
    try {
      const res = await alumnosService.getAlumnoById(Number(id));
      const full = res.data || res;
      if (full) {
        setAlumnoSeleccionado(full);
        setAlumnoFichaEditable({ 
          ...full,
          nivel: full.grupo?.nivel || full.nivel || '',
          grado: full.grupo?.grado || full.grado || '',
          seccion: full.grupo?.seccion || full.seccion || ''
        });
        setPadresAlumno(full.padres || full.padresLista || []);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const cargarEstadoCuenta = async () => {
    if (!id) return;
    try {
      const res: any = await alumnosService.getEstadoCuenta(Number(id));
      setEstadoCuentaAlumno(res.data?.data || res.data || []);
    } catch (err) {
      console.error(err);
    }
  };

  const previsualizarPlan = async (meses: number) => {
    if (!id) return;
    setLoadingPlan(true);
    setMesesPlanSeleccionado(meses);
    try {
      const res: any = await alumnosService.previewPlanPagos(Number(id), meses);
      setPlanPreview(res.data?.data || res.data || []);
    } catch (err: any) {
      alert(err.response?.data?.message || 'Error al previsualizar plan.');
      setPlanPreview(null);
      setMesesPlanSeleccionado(null);
    } finally {
      setLoadingPlan(false);
    }
  };

  const asignarPlan = async () => {
    if (!id || !mesesPlanSeleccionado) return;
    if (!window.confirm(`¿Estás seguro de asignar el plan de ${mesesPlanSeleccionado} meses?`)) return;
    try {
      await alumnosService.generarPlanPagos(Number(id), mesesPlanSeleccionado);
      alert('Plan de pagos generado y guardado correctamente.');
      setPlanPreview(null);
      setMesesPlanSeleccionado(null);
      setAlumnoSeleccionado((prev: any) => ({
        ...prev,
        planPago: { nombre: `Plan de ${mesesPlanSeleccionado} Meses` }
      }));
      cargarEstadoCuenta();
    } catch (err: any) {
      alert(err.response?.data?.message || 'Error al asignar el plan.');
    }
  };

  const resetearPlan = async () => {
    if (!id) return;
    if (!window.confirm('¿Estás seguro de eliminar el plan actual? Se borrarán todos los cargos pendientes. Los cargos pagados no se pueden eliminar.')) return;
    try {
      await alumnosService.eliminarPlanPagos(Number(id));
      alert('Adeudos y plan actual eliminados. Puedes generar uno nuevo.');
      setPlanPreview(null);
      setMesesPlanSeleccionado(null);
      setEstadoCuentaAlumno([]);
      setAlumnoSeleccionado((prev: any) => ({
        ...prev,
        planPago: null
      }));
      cargarEstadoCuenta();
    } catch (err: any) {
      alert(err.response?.data?.message || 'Error al resetear el plan.');
    }
  };

  const handleGuardarFicha = async () => {
    try {
      const payload = { ...alumnoFichaEditable };
      if (payload.nivel && payload.grado && payload.seccion) {
        const grupoMatch = gruposData.find((g: any) => 
          g.nivel?.toUpperCase() === payload.nivel?.toUpperCase() && 
          String(g.grado) === String(payload.grado) && 
          g.seccion?.toUpperCase() === payload.seccion?.toUpperCase()
        );
        if (grupoMatch) payload.grupoId = grupoMatch.grupoId || grupoMatch.id;
      }
      await alumnosService.updateAlumno(Number(id), payload);
      alert('Información actualizada correctamente');
      setAlumnoSeleccionado({ 
        ...payload,
        grupo: payload.grupoId ? {
          nivel: payload.nivel,
          grado: payload.grado,
          seccion: payload.seccion,
          nombre: `${payload.grado}°${payload.seccion} ${payload.nivel}`
        } : payload.grupo
      });
    } catch (error) {
      console.error('Error actualizando alumno', error);
      alert('Error al guardar los cambios');
    }
  };

  const handleUploadComprobante = async (e: React.ChangeEvent<HTMLInputElement>, pagoId: number) => {
    if (!e.target.files || e.target.files.length === 0) return;
    const file = e.target.files[0];
    
    // Validaciones basicas
    const validMimes = ['image/jpeg', 'image/png', 'application/pdf', 'image/webp'];
    if (!validMimes.includes(file.type)) {
      alert('Solo se permiten archivos JPG, PNG, WEBP o PDF.');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      alert('El archivo no debe exceder 5MB.');
      return;
    }

    const formData = new FormData();
    formData.append('comprobante', file);

    setUploadingPagoId(pagoId);
    try {
      await pagosService.subirComprobante(pagoId, formData);
      alert('Comprobante subido exitosamente.');
      cargarPagosAlumnoFicha(); // Recargar historial
    } catch (error: any) {
      console.error('Error subiendo comprobante', error);
      alert(error.response?.data?.message || 'Error al subir el comprobante.');
    } finally {
      setUploadingPagoId(null);
    }
  };

  const handleDownloadComprobante = async (pagoId: number) => {
    try {
      const response = await pagosService.descargarComprobante(pagoId);
      const url = window.URL.createObjectURL(new Blob([response.data], { type: response.headers['content-type'] }));
      window.open(url, '_blank');
    } catch (error: any) {
      console.error('Error descargando comprobante', error);
      alert('No se pudo descargar el comprobante.');
    }
  };

  const buscarTutoresParaVincular = async (e?: React.FormEvent) => {
    if (busquedaVincularTutor.length < 2) { setTutoresParaVincular([]); return; }
    try {
      const res = await tutoresService.getTutores({ q: busquedaVincularTutor, limit: 5 });
      const data = res.data?.data || res.data || res;
      if (data) setTutoresParaVincular(data as Tutor[]);
    } catch (e) { console.error(e); setTutoresParaVincular([]); }
  };

  const confirmarVinculacionTutor = async (tutor: any) => {
    try {
      await tutoresService.vincularAlumno(tutor.tutorId || tutor.id as number, {
        alumnoId: Number(id), tipoRelacion: 'tutor', esResponsableFinanciero: false, puedeRecoger: true
      });
      alert('Tutor vinculado correctamente');
      setModalVincularTutor(false);
      setBusquedaVincularTutor('');
      cargarFichaAlumno();
    } catch (e: any) { alert(e?.response?.data?.message || 'Error al vincular tutor'); }
  };

  const desvincularTutor = async (tutorId: number) => {
    if (!confirm('¿Seguro que deseas desvincular este tutor del alumno?')) return;
    try {
      await tutoresService.desvincularAlumno(tutorId, Number(id));
      alert('Tutor desvinculado correctamente.');
      cargarFichaAlumno();
    } catch (e: any) { alert(e?.response?.data?.message || 'Error al desvincular'); }
  };

  const cargarPagosAlumnoFicha = async () => {
    if (!id) return;
    try {
      const resCal: any = await pagosService.obtenerCalendario(Number(id));
      if (resCal.data) setEstadoCuentaAlumno(resCal.data?.data || resCal.data || []);
    } catch (e) { console.error(e); }
    try {
      const resPagos: any = await pagosService.obtenerPagos({ alumnoId: Number(id) });
      if (resPagos.data) setHistorialPagosAlumno(resPagos.data?.data || resPagos.data || []);
    } catch (e) { console.error(e); }
  };

  const cargarCalificacionesAlumno = async () => {
    if (!id) return;
    try {
      const res: any = await calificacionesService.obtenerPorAlumno(Number(id));
      const data = res.data?.data || res.data || [];
      const todas = Array.isArray(data) ? data : (data.calificaciones || data.data || []);
      
      const materiasMap = new Map();
      todas.forEach((c: any) => {
        const matNombre = c.grupoMateria?.materia || c.materia?.nombre || 'Materia Desconocida';
        if (!materiasMap.has(matNombre)) {
          materiasMap.set(matNombre, { 
            nombre: matNombre, 
            tipo: c.grupoMateria?.tipo || c.tipoEvaluacion || 'curricular',
            valores: [],
            trimestre1: '-',
            trimestre2: '-',
            trimestre3: '-'
          });
        }
        
        const m = materiasMap.get(matNombre);
        if (c.valor !== null && c.valor !== undefined) {
           m.valores.push(c.valor);
           const periodoStr = String(c.periodo || c.periodoId || '').toUpperCase();
           if (periodoStr.includes('1') || periodoStr === 'TRIMESTRE_1') m.trimestre1 = c.valor;
           else if (periodoStr.includes('2') || periodoStr === 'TRIMESTRE_2') m.trimestre2 = c.valor;
           else if (periodoStr.includes('3') || periodoStr === 'TRIMESTRE_3') m.trimestre3 = c.valor;
        }
      });

      const grouped = Array.from(materiasMap.values()).map((m: any) => {
         if (m.valores.length > 0) {
           const sum = m.valores.reduce((a:number, b:number) => a + b, 0);
           m.promedio = Number((sum / m.valores.length).toFixed(1));
         } else {
           m.promedio = '-';
         }
         return m;
      });

      setCalificacionesAlumno(grouped.filter((c: any) => c.tipo === 'curricular' || c.tipo === 'numerica' || !c.tipo));
      setCalificacionesExtra(grouped.filter((c: any) => c.tipo === 'extracurricular' || c.tipo === 'taller'));
    } catch (e) { console.error(e); }
  };

  const handleRegistrarPago = () => {
    if (id) {
      navigate(`/pagos?alumnoId=${id}`);
    }
  };

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-navy-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!alumnoSeleccionado) {
    return (
      <div className="h-full flex flex-col items-center justify-center text-gray-500">
        <UserPlus size={48} className="opacity-20 mb-4" />
        <p>No se encontró el alumno.</p>
        <button onClick={() => navigate('/alumnos')} className="mt-4 text-navy-600 hover:underline">Volver al directorio</button>
      </div>
    );
  }

  const gruposArray = Array.isArray(gruposData) ? gruposData : [];
  const gradosDisponiblesEdit = Array.from(new Set(gruposArray.filter(g => g.nivel?.toUpperCase() === (alumnoFichaEditable.nivel as string)?.toUpperCase()).map(g => g.grado))).sort();
  const seccionesDisponiblesEdit = Array.from(new Set(gruposArray.filter(g => g.nivel?.toUpperCase() === (alumnoFichaEditable.nivel as string)?.toUpperCase() && String(g.grado) === String(alumnoFichaEditable.grado)).map(g => g.seccion))).sort();

  return (
    <div className="h-full flex flex-col overflow-y-auto pr-2 pb-8">
      {/* Header */}
      <div className="flex items-center gap-4 mb-6">
        <button onClick={() => navigate('/alumnos')} className="p-2 rounded-xl border border-gray-200 hover:bg-gray-50 text-gray-500 transition-colors">
          <ArrowLeft size={18} />
        </button>
        <div className="flex-1">
          <h2 className="text-2xl font-bold text-navy-800">Expediente del Alumno</h2>
        </div>
      </div>

      <div className="flex flex-col lg:flex-row gap-6">
        {/* Left Column: Profile Card */}
        <div className="lg:w-1/3">
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 text-center">
            <div className="w-24 h-24 rounded-full bg-gradient-to-br from-navy-500 to-navy-700 mx-auto flex items-center justify-center text-white text-4xl font-bold uppercase shadow-md mb-4">
              {alumnoSeleccionado?.nombre.charAt(0)}
            </div>
            <h2 className="text-xl font-bold text-navy-800">{alumnoSeleccionado?.nombre}</h2>
            <p className="text-gray-500 mb-3">{alumnoSeleccionado?.matricula}</p>
            
            <span className={`px-3 py-1 rounded-full text-xs font-semibold inline-block mb-6 ${
              alumnoSeleccionado.estado === 'Activo' ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-700'
            }`}>
              {alumnoSeleccionado.estado || 'Activo'}
            </span>

            <div className="space-y-3">
              {!alumnoSeleccionado.planPago ? (
                <button className="w-full px-4 py-2 bg-orange-600 text-white rounded-xl hover:bg-orange-700 font-medium" onClick={() => setTabAlumnoFicha('planes')}>
                  Asignar Plan de Pagos
                </button>
              ) : (
                <button className="w-full px-4 py-2 bg-navy-600 text-white rounded-xl hover:bg-navy-700 font-medium" onClick={handleRegistrarPago}>
                  Registrar Pago
                </button>
              )}
              {alumnoSeleccionado.beca ? (
                <div className="w-full px-4 py-3 bg-emerald-50 rounded-xl border border-emerald-100 text-sm">
                  <div className="flex items-center gap-2 mb-1 font-bold text-emerald-800">
                    <Award size={16} className="text-emerald-600" /> Beca Activa
                  </div>
                  <p className="text-emerald-700 font-medium">{alumnoSeleccionado.beca.nombreBeca || alumnoSeleccionado.beca.nombre}</p>
                  <p className="text-xs text-emerald-600 font-semibold">{alumnoSeleccionado.beca.porcentaje}% de descuento</p>
                </div>
              ) : (
                <button 
                  className="w-full px-4 py-2 flex items-center justify-center gap-2 bg-emerald-50 text-emerald-700 rounded-xl hover:bg-emerald-100 font-medium"
                  onClick={() => navigate(`/becas?alumnoId=${alumnoSeleccionado.id || alumnoSeleccionado.alumnoId}&alumnoNombre=${encodeURIComponent(alumnoSeleccionado.nombre)}`)}
                >
                  <Award size={16} /> Asignar Beca
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Right Column: Tabs and Content */}
        <div className="lg:w-2/3 flex flex-col">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden flex flex-col min-h-[600px]">
            <div className="sticky top-0 bg-white z-10 border-b">
              <div className="flex overflow-x-auto whitespace-nowrap scrollbar-hide">
                <button 
                  className={`px-6 py-4 text-sm font-medium transition-colors ${tabAlumnoFicha === 'academicos' ? 'text-navy-700 border-b-2 border-navy-700 bg-gray-50/50' : 'text-gray-500 hover:bg-gray-50'}`}
                  onClick={() => setTabAlumnoFicha('academicos')}
                >
                  Info Escolar
                </button>
                <button 
                  className={`px-6 py-4 text-sm font-medium flex items-center gap-2 transition-colors ${tabAlumnoFicha === 'tutores' ? 'text-navy-700 border-b-2 border-navy-700 bg-gray-50/50' : 'text-gray-500 hover:bg-gray-50'}`}
                  onClick={() => setTabAlumnoFicha('tutores')}
                >
                  <Users size={16} /> Familia
                </button>
                <button 
                  className={`px-6 py-4 text-sm font-medium flex items-center gap-2 transition-colors ${tabAlumnoFicha === 'planes' ? 'text-navy-700 border-b-2 border-navy-700 bg-gray-50/50' : 'text-gray-500 hover:bg-gray-50'}`}
                  onClick={() => setTabAlumnoFicha('planes')}
                >
                  <Calendar size={16} /> Plan de Pago
                </button>
                <button 
                  className={`px-6 py-4 text-sm font-medium flex items-center gap-2 transition-colors ${tabAlumnoFicha === 'estado_cuenta' ? 'text-navy-700 border-b-2 border-navy-700 bg-gray-50/50' : 'text-gray-500 hover:bg-gray-50'}`}
                  onClick={() => { setTabAlumnoFicha('estado_cuenta'); cargarPagosAlumnoFicha(); }}
                >
                  <Clock size={16} /> Estado de Cuenta
                </button>
                <button 
                  className={`px-6 py-4 text-sm font-medium flex items-center gap-2 transition-colors ${tabAlumnoFicha === 'historial_pagos' ? 'text-navy-700 border-b-2 border-navy-700 bg-gray-50/50' : 'text-gray-500 hover:bg-gray-50'}`}
                  onClick={() => { setTabAlumnoFicha('historial_pagos'); cargarPagosAlumnoFicha(); }}
                >
                  <Receipt size={16} /> Historial Pagos
                </button>
                <button 
                  className={`px-6 py-4 text-sm font-medium flex items-center gap-2 transition-colors ${tabAlumnoFicha === 'calificaciones' ? 'text-navy-700 border-b-2 border-navy-700 bg-gray-50/50' : 'text-gray-500 hover:bg-gray-50'}`}
                  onClick={() => { setTabAlumnoFicha('calificaciones'); cargarCalificacionesAlumno(); }}
                >
                  <GraduationCap size={16} /> Calificaciones
                </button>
              </div>
            </div>

            <div className="p-6 flex-1 bg-gray-50/30">
              {tabAlumnoFicha === 'academicos' && (
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Nombre Completo</label>
                      <input 
                        className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none" 
                        value={alumnoFichaEditable.nombre || ''}
                        onChange={(e) => setAlumnoFichaEditable({...alumnoFichaEditable, nombre: e.target.value})}
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Fecha de Nacimiento</label>
                      <input 
                        type="date"
                        className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none text-gray-600" 
                        value={alumnoFichaEditable.fechaNacimiento ? alumnoFichaEditable.fechaNacimiento.split('T')[0] : ''}
                        onChange={(e) => setAlumnoFichaEditable({...alumnoFichaEditable, fechaNacimiento: e.target.value})}
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Matrícula</label>
                      <input 
                        className="w-full px-4 py-2 rounded-xl border border-gray-200 bg-gray-50 text-gray-500 outline-none cursor-not-allowed" 
                        value={alumnoSeleccionado?.matricula || ''}
                        disabled
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">CURP</label>
                      <input 
                        className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none uppercase" 
                        value={alumnoFichaEditable.curp || ''}
                        onChange={(e) => setAlumnoFichaEditable({...alumnoFichaEditable, curp: e.target.value.toUpperCase()})}
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Nivel Educativo</label>
                      <select 
                        className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                        value={alumnoFichaEditable.nivel || ''}
                        onChange={(e) => setAlumnoFichaEditable({...alumnoFichaEditable, nivel: e.target.value, grado: '', seccion: ''})}
                      >
                        <option value="">- Selecciona Nivel -</option>
                        {nivelesDisponibles.map(n => <option key={n} value={n}>{n}</option>)}
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Grado</label>
                      <select 
                        className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                        value={alumnoFichaEditable.grado || ''}
                        onChange={(e) => setAlumnoFichaEditable({...alumnoFichaEditable, grado: e.target.value, seccion: ''})}
                      >
                        <option value="">- Selecciona Grado -</option>
                        {gradosDisponiblesEdit.map(g => (
                          <option key={g} value={g}>{g}°</option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Grupo</label>
                      <select 
                        className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                        value={alumnoFichaEditable.seccion || ''}
                        onChange={(e) => setAlumnoFichaEditable({...alumnoFichaEditable, seccion: e.target.value})}
                      >
                        <option value="">- Selecciona Grupo -</option>
                        {seccionesDisponiblesEdit.map(s => (
                          <option key={s} value={s}>{s}</option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Estado / Estatus</label>
                      <select 
                        className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                        value={alumnoFichaEditable.estado || 'Activo'}
                        onChange={(e) => setAlumnoFichaEditable({...alumnoFichaEditable, estado: e.target.value})}
                      >
                        <option value="Activo">Activo</option>
                        <option value="Baja Temporal">Baja Temporal</option>
                        <option value="Baja Definitiva">Baja Definitiva</option>
                        <option value="Egresado">Egresado</option>
                      </select>
                    </div>
                    <div className="col-span-2">
                      <label className="block text-sm font-medium text-gray-700 mb-1">Personas autorizadas para recoger (separadas por coma)</label>
                      <textarea 
                        rows={3}
                        className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none resize-none"
                        value={alumnoFichaEditable.personasAutorizadas || ''}
                        onChange={(e) => setAlumnoFichaEditable({...alumnoFichaEditable, personasAutorizadas: e.target.value})}
                      ></textarea>
                    </div>
                  </div>
                  <div className="pt-4 flex justify-end items-center">
                    <button 
                      onClick={handleGuardarFicha}
                      className="px-6 py-2 bg-navy-800 text-white rounded-xl hover:bg-navy-900 font-medium shadow-sm transition-colors"
                    >
                      Guardar Expediente
                    </button>
                  </div>
                </div>
              )}

              {tabAlumnoFicha === 'tutores' && (
                <div>
                  <div className="flex justify-between items-center mb-4">
                    <h3 className="font-semibold text-gray-700">Tutores vinculados a este alumno</h3>
                    <button className="px-3 py-1.5 text-xs font-medium text-navy-600 bg-navy-50 rounded-lg hover:bg-navy-100" onClick={() => { setModalVincularTutor(true); setBusquedaVincularTutor(''); setTutoresParaVincular([]); }}>
                      + Vincular Tutor
                    </button>
                  </div>
                  <div className="space-y-3">
                    {padresAlumno.length === 0 ? (
                      <div className="text-center p-6 text-gray-500 border border-dashed rounded-xl">No hay tutores vinculados a este expediente.</div>
                    ) : padresAlumno.map((t: any, idx: number) => (
                      <div key={idx} className="bg-white border rounded-xl p-4 flex justify-between items-center">
                        <div>
                          <div className="font-bold text-navy-800 flex items-center gap-2">
                            {t.nombre || t.nombreCompleto}
                            {t.esTutor && <span className="px-2 py-0.5 bg-navy-100 text-navy-700 text-[10px] rounded-full uppercase font-bold">Responsable Financiero</span>}
                          </div>
                          <div className="text-sm text-gray-600 mt-1">{t.tipoRelacion || 'Tutor'}</div>
                          <div className="text-xs text-gray-500 mt-1 flex items-center gap-3">
                            <span>Tel: {t.telefono || 'Sin teléfono'}</span>
                            <span>{t.email || t.correoElectronico || 'Sin correo'}</span>
                          </div>
                        </div>
                        <button className="px-3 py-1.5 text-xs font-medium text-red-600 bg-red-50 rounded-lg hover:bg-red-100" onClick={() => desvincularTutor(t.id || t.tutorId)}>Desvincular</button>
                      </div>
                    ))}
                  </div>

                  {/* Modal Vincular Tutor */}
                  {modalVincularTutor && (
                    <div className="fixed inset-0 bg-black/30 z-50 flex items-center justify-center" onClick={() => setModalVincularTutor(false)}>
                      <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl" onClick={e => e.stopPropagation()}>
                        <h3 className="font-bold text-lg text-navy-800 mb-4">Vincular Tutor</h3>
                        <input 
                          type="text" placeholder="Buscar tutor por nombre..." 
                          className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none mb-3"
                          value={busquedaVincularTutor}
                          onChange={(e) => { setBusquedaVincularTutor(e.target.value); }}
                          onKeyUp={() => buscarTutoresParaVincular()}
                        />
                        <div className="space-y-2 max-h-60 overflow-y-auto">
                          {tutoresParaVincular.map((t: any) => (
                            <div key={t.id || t.tutorId} className="flex justify-between items-center border rounded-lg p-3 hover:bg-gray-50">
                              <div>
                                <div className="font-medium text-gray-900">{t.nombre || t.nombreCompleto}</div>
                                <div className="text-xs text-gray-500">{t.telefono || ''} {t.email || t.correoElectronico || ''}</div>
                              </div>
                              <button className="px-3 py-1 text-xs font-medium bg-navy-600 text-white rounded-lg hover:bg-navy-700" onClick={() => confirmarVinculacionTutor(t)}>Vincular</button>
                            </div>
                          ))}
                          {busquedaVincularTutor.length >= 2 && tutoresParaVincular.length === 0 && (
                            <div className="text-center text-gray-400 py-4 text-sm">No se encontraron tutores.</div>
                          )}
                        </div>
                        <button className="mt-4 w-full px-4 py-2 border border-gray-200 rounded-xl text-gray-600 hover:bg-gray-50" onClick={() => setModalVincularTutor(false)}>Cancelar</button>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {tabAlumnoFicha === 'planes' && (
                <div className="py-4">
                  {alumnoSeleccionado?.planPago ? (
                    <div className="text-center py-8">
                      <Calendar size={40} className="mx-auto mb-3 text-emerald-500" />
                      <h4 className="font-bold text-gray-900 mb-2">
                        Plan Actual: {alumnoSeleccionado?.planPago?.nombre || 'Plan Activo'}
                      </h4>
                      <p className="text-sm text-gray-500 mb-6">Puedes revisar sus saldos y cargos pendientes en la pestaña de Estado de Cuenta.</p>
                      <button 
                        onClick={resetearPlan}
                        className="px-4 py-2 border border-red-200 text-red-600 bg-red-50 rounded-lg hover:bg-red-100 font-medium text-sm transition-colors"
                      >
                        Eliminar / Resetear Plan
                      </button>
                    </div>
                  ) : (
                    <div>
                      <div className="flex justify-between items-center mb-6">
                        <h3 className="font-semibold text-gray-700">Asignar Plan de Pagos</h3>
                      </div>
                      
                      {!planPreview ? (
                        <div className="grid grid-cols-2 gap-4">
                          <button 
                            onClick={() => previsualizarPlan(10)}
                            className="p-6 border border-gray-200 rounded-2xl hover:border-navy-500 hover:shadow-md transition-all text-left bg-white"
                          >
                            <div className="flex justify-between items-start mb-4">
                              <div className="w-12 h-12 bg-navy-50 text-navy-600 rounded-full flex items-center justify-center font-bold text-lg">
                                10
                              </div>
                            </div>
                            <h4 className="font-bold text-gray-900 text-lg mb-1">Plan de 10 Meses</h4>
                            <p className="text-sm text-gray-500">Distribuye el pago del ciclo en 10 mensualidades equitativas (Septiembre - Junio).</p>
                          </button>

                          <button 
                            onClick={() => previsualizarPlan(12)}
                            className="p-6 border border-gray-200 rounded-2xl hover:border-navy-500 hover:shadow-md transition-all text-left bg-white"
                          >
                            <div className="flex justify-between items-start mb-4">
                              <div className="w-12 h-12 bg-emerald-50 text-emerald-600 rounded-full flex items-center justify-center font-bold text-lg">
                                12
                              </div>
                            </div>
                            <h4 className="font-bold text-gray-900 text-lg mb-1">Plan de 12 Meses</h4>
                            <p className="text-sm text-gray-500">Mensualidad más baja. Distribuye el costo total en 12 meses. Diciembre incluye cobro doble por enero.</p>
                          </button>
                        </div>
                      ) : (
                        <div>
                          <div className="flex items-center gap-4 mb-4">
                            <button 
                              onClick={() => { setPlanPreview(null); setMesesPlanSeleccionado(null); }}
                              className="text-sm text-gray-500 hover:text-navy-600 font-medium"
                            >
                              &larr; Cambiar opción
                            </button>
                            <h4 className="font-bold text-gray-900">Vista Previa - Plan {mesesPlanSeleccionado} Meses</h4>
                            <button 
                              onClick={asignarPlan}
                              className="ml-auto px-4 py-2 bg-emerald-600 text-white font-medium text-sm rounded-lg hover:bg-emerald-700 shadow-sm transition-colors"
                            >
                              Confirmar y Asignar Plan
                            </button>
                          </div>
                          
                          <div className="overflow-x-auto border border-gray-100 rounded-xl bg-white">
                            <table className="w-full text-sm text-left text-gray-600">
                              <thead className="bg-gray-50 text-gray-700">
                                <tr>
                                  <th className="px-4 py-3 font-semibold">Concepto</th>
                                  <th className="px-4 py-3 font-semibold">Mes</th>
                                  <th className="px-4 py-3 font-semibold text-right">Vencimiento</th>
                                  <th className="px-4 py-3 font-semibold text-right">Monto Original</th>
                                </tr>
                              </thead>
                              <tbody className="divide-y divide-gray-50">
                                {planPreview.calendario?.map((item: any, idx: number) => (
                                  <tr key={idx} className="hover:bg-gray-50/50">
                                    <td className="px-4 py-3 capitalize">{item.concepto}</td>
                                    <td className="px-4 py-3 capitalize">{item.mes}</td>
                                    <td className="px-4 py-3 text-right">{item.fechaVencimiento?.split('T')[0]}</td>
                                    <td className="px-4 py-3 text-right font-medium text-gray-900">${Number(item.montoOriginal).toFixed(2)}</td>
                                  </tr>
                                ))}
                                <tr className="bg-gray-50 font-bold text-gray-900">
                                  <td colSpan={3} className="px-4 py-3 text-right">Total Ciclo:</td>
                                  <td className="px-4 py-3 text-right">
                                    ${planPreview.calendario?.reduce((acc: number, cur: any) => acc + Number(cur.montoOriginal), 0).toFixed(2)}
                                  </td>
                                </tr>
                              </tbody>
                            </table>
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              )}

              {tabAlumnoFicha === 'estado_cuenta' && (
                <div>
                  <div className="flex justify-between items-center mb-4">
                    <h3 className="font-semibold text-gray-700">Estado de Cuenta</h3>
                    <button className="px-3 py-1.5 text-xs font-medium text-navy-600 bg-navy-50 rounded-lg hover:bg-navy-100" onClick={cargarPagosAlumnoFicha}>Actualizar</button>
                  </div>
                  {estadoCuentaAlumno.length === 0 ? (
                    <div className="text-center p-6 text-gray-500">No hay registro de estado de cuenta para este alumno.</div>
                  ) : (
                    <div className="relative border-l-2 border-gray-200 ml-3 space-y-6">
                      {estadoCuentaAlumno.map((item: any, idx: number) => {
                        const isPagado = item.estadoCobro === 'pagado' || item.estadoCobro === 'liquidado';
                        const isPendiente = item.estadoCobro === 'pendiente';
                        const isVencido = item.estadoCobro === 'vencido';
                        return (
                          <div key={idx} className="ml-6 relative">
                            <span className={`absolute flex items-center justify-center w-6 h-6 rounded-full -left-9 ring-4 ring-white ${
                              isPagado ? 'bg-emerald-100' : isPendiente ? 'bg-amber-100' : 'bg-red-100'
                            }`}>
                              {isPagado ? '✓' : isPendiente ? '●' : '!'}
                            </span>
                            <div className="bg-white p-4 rounded-xl border border-gray-100 shadow-sm">
                              <div className="flex justify-between items-start mb-1">
                                <h4 className="font-medium text-gray-800">{item.concepto} {item.mes || ''}</h4>
                                <span className={`text-xs font-semibold px-2 py-1 rounded-full ${
                                  isPagado ? 'bg-emerald-100 text-emerald-700' : isPendiente ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700'
                                }`}>{(item.estadoCobro || '').toUpperCase()}</span>
                              </div>
                              <p className="text-xs text-gray-500 mb-2">Vencimiento: {item.fechaVencimiento?.split('T')[0]}</p>
                              <div className="grid grid-cols-2 gap-2 text-sm mt-3">
                                <div><p className="text-gray-500 text-xs">Monto Original</p><p className="font-medium text-gray-700">${Number(item.montoOriginal || 0).toFixed(2)}</p></div>
                                {Number(item.montoRecargo) > 0 && <div><p className="text-gray-500 text-xs">Recargo</p><p className="font-medium text-red-600">+${Number(item.montoRecargo).toFixed(2)}</p></div>}
                                <div><p className="text-gray-500 text-xs">Monto Pagado</p><p className="font-medium text-emerald-600">${Number(item.montoPagado || 0).toFixed(2)}</p></div>
                                <div><p className="text-gray-500 text-xs">Saldo Pendiente</p><p className={`font-bold ${Number(item.saldoPendiente) > 0 ? 'text-navy-700' : 'text-gray-600'}`}>${Number(item.saldoPendiente || 0).toFixed(2)}</p></div>
                              </div>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              )}

              {tabAlumnoFicha === 'historial_pagos' && (
                <div>
                  <div className="flex justify-between items-center mb-4">
                    <h3 className="font-semibold text-gray-700">Recibos y Comprobantes</h3>
                    <button className="px-3 py-1.5 text-xs font-medium text-navy-600 bg-navy-50 rounded-lg hover:bg-navy-100" onClick={cargarPagosAlumnoFicha}>Actualizar</button>
                  </div>
                  {historialPagosAlumno.length === 0 ? (
                    <div className="text-center p-6 text-gray-500">No hay recibos de pagos para este alumno.</div>
                  ) : (
                    <div className="overflow-x-auto border border-gray-100 rounded-xl bg-white">
                      <table className="w-full text-left text-sm text-gray-600">
                        <thead className="bg-gray-50 text-gray-700 uppercase text-xs">
                          <tr>
                            <th className="px-4 py-3">Fecha</th>
                            <th className="px-4 py-3">Concepto</th>
                            <th className="px-4 py-3">Monto</th>
                            <th className="px-4 py-3 text-center">Comprobante</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100">
                          {historialPagosAlumno.map((pago: any, idx: number) => (
                            <tr key={idx} className="hover:bg-gray-50/50">
                              <td className="px-4 py-3 font-medium text-gray-900">{pago.fecha?.split('T')[0] || pago.createdAt?.split('T')[0]}</td>
                              <td className="px-4 py-3">{pago.concepto}</td>
                              <td className="px-4 py-3 text-emerald-600 font-semibold">${Number(pago.monto || pago.montoAbonado || 0).toFixed(2)}</td>
                              <td className="px-4 py-3 text-center">
                                {pago.documentos && pago.documentos.length > 0 ? (
                                  <button
                                    onClick={() => handleDownloadComprobante((pago.id || pago.pagoId))}
                                    className="inline-flex items-center gap-1.5 px-3 py-1 bg-blue-50 text-blue-600 rounded-lg font-medium text-xs hover:bg-blue-100 transition-colors"
                                    title="Descargar comprobante"
                                  >
                                    <Download size={14} /> Ver Comprobante
                                  </button>
                                ) : (
                                  <label className="inline-flex items-center gap-1.5 px-3 py-1 bg-gray-50 border border-gray-200 text-gray-500 rounded-lg font-medium text-xs hover:bg-gray-100 transition-colors cursor-pointer" title="Adjuntar comprobante">
                                    {uploadingPagoId === (pago.id || pago.pagoId) ? (
                                      <><Loader2 size={14} className="animate-spin" /> Subiendo...</>
                                    ) : (
                                      <><Paperclip size={14} /> Adjuntar</>
                                    )}
                                    <input 
                                      type="file" 
                                      className="hidden" 
                                      accept=".jpg,.jpeg,.png,.webp,.pdf"
                                      disabled={uploadingPagoId === (pago.id || pago.pagoId)}
                                      onChange={(e) => handleUploadComprobante(e, (pago.id || pago.pagoId))} 
                                    />
                                  </label>
                                )}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              )}

              {tabAlumnoFicha === 'calificaciones' && (
                <div>
                  <div className="flex justify-between items-center mb-4">
                    <h3 className="font-semibold text-gray-700">Boleta Virtual (Historial Académico)</h3>
                    <button className="px-3 py-1.5 text-xs font-medium text-navy-600 bg-navy-50 rounded-lg hover:bg-navy-100" onClick={cargarCalificacionesAlumno}>Actualizar</button>
                  </div>
                  {calificacionesAlumno.length === 0 && calificacionesExtra.length === 0 ? (
                    <div className="p-6 bg-gray-50 rounded-xl border border-gray-100 text-center">
                      <GraduationCap size={32} className="mx-auto mb-2 text-gray-400" />
                      <p className="text-gray-500 text-sm">El grupo de este alumno aún no tiene materias asignadas o no hay calificaciones registradas.</p>
                    </div>
                  ) : (
                    <>
                      {calificacionesAlumno.length > 0 && (
                        <>
                          <h4 className="font-bold text-navy-800 mb-3">Materias Curriculares</h4>
                          <div className="overflow-x-auto border border-gray-100 rounded-xl mb-6 bg-white">
                            <table className="w-full text-sm text-left">
                              <thead className="bg-gray-50 text-gray-600">
                                <tr>
                                  <th className="p-3 font-semibold">Materia</th>
                                  <th className="p-3 font-semibold text-center w-28">Trim. 1</th>
                                  <th className="p-3 font-semibold text-center w-28">Trim. 2</th>
                                  <th className="p-3 font-semibold text-center w-28">Trim. 3</th>
                                  <th className="p-3 font-semibold text-center w-24">Promedio</th>
                                </tr>
                              </thead>
                              <tbody>
                                {calificacionesAlumno.map((mat: any, idx: number) => (
                                  <tr key={idx} className="border-b">
                                    <td className="p-3 font-medium text-gray-800">{mat.nombre || mat.materia}</td>
                                    <td className="p-3 text-center">{mat.T1?.v ?? mat.trimestre1 ?? '-'}</td>
                                    <td className="p-3 text-center">{mat.T2?.v ?? mat.trimestre2 ?? '-'}</td>
                                    <td className="p-3 text-center">{mat.T3?.v ?? mat.trimestre3 ?? '-'}</td>
                                    <td className={`p-3 text-center font-bold ${(mat.prom || mat.promedio) < 6 ? 'text-red-500' : 'text-emerald-600'}`}>{mat.prom ?? mat.promedio ?? '-'}</td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          </div>
                        </>
                      )}
                      {calificacionesExtra.length > 0 && (
                        <>
                          <h4 className="font-bold text-navy-800 mb-3">Clubes / Extracurriculares</h4>
                          <div className="overflow-x-auto border border-gray-100 rounded-xl bg-white">
                            <table className="w-full text-sm text-left">
                              <thead className="bg-gray-50 text-gray-600">
                                <tr>
                                  <th className="p-3 font-semibold">Club</th>
                                  <th className="p-3 font-semibold text-center w-28">Trim. 1</th>
                                  <th className="p-3 font-semibold text-center w-28">Trim. 2</th>
                                  <th className="p-3 font-semibold text-center w-28">Trim. 3</th>
                                  <th className="p-3 font-semibold text-center w-24">Promedio</th>
                                </tr>
                              </thead>
                              <tbody>
                                {calificacionesExtra.map((club: any, idx: number) => (
                                  <tr key={idx} className="border-b">
                                    <td className="p-3 font-medium text-gray-800 uppercase">{club.nombre || club.materia}</td>
                                    <td className="p-3 text-center">{club.T1?.v ?? club.trimestre1 ?? '-'}</td>
                                    <td className="p-3 text-center">{club.T2?.v ?? club.trimestre2 ?? '-'}</td>
                                    <td className="p-3 text-center">{club.T3?.v ?? club.trimestre3 ?? '-'}</td>
                                    <td className={`p-3 text-center font-bold ${(club.prom || club.promedio) < 6 ? 'text-red-500' : 'text-emerald-600'}`}>{club.prom ?? club.promedio ?? '-'}</td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          </div>
                        </>
                      )}
                    </>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
