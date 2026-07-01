import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { UserPlus, Upload, Download, Search, X, Users, Calendar, Clock, Receipt, GraduationCap, Award } from 'lucide-react';
import api from '../services/api';
import { generateCURP } from '../utils/curp';
import { alumnosService } from '../services/alumnos.service';
import { tutoresService } from '../services/tutores.service';
import type { Alumno, Tutor } from '../types';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Modal } from '../components/ui/Modal';

export function Alumnos() {
  const navigate = useNavigate();
  const [alumnos, setAlumnos] = useState<Alumno[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  
  // Filters
  const [busqueda, setBusqueda] = useState('');
  const [filtroEstado, setFiltroEstado] = useState('');
  const [filtroNivel, setFiltroNivel] = useState('');
  const [filtroGrado, setFiltroGrado] = useState('');
  const [filtroSeccion, setFiltroSeccion] = useState('');
  const [pagina, setPagina] = useState(1);
  const [paginasTotales, setPaginasTotales] = useState(1);
  
  // Ficha Alumno
  const [alumnoSeleccionado, setAlumnoSeleccionado] = useState<Alumno | null>(null);
  const [tabAlumnoFicha, setTabAlumnoFicha] = useState('academicos');
  const [alumnoFichaEditable, setAlumnoFichaEditable] = useState<Partial<Alumno>>({});
  
  // Tab Directorio y Tutores
  const [tabDirectorio, setTabDirectorio] = useState<'alumnos'|'tutores'>('alumnos');
  
  const [tutores, setTutores] = useState<Tutor[]>([]);
  const [loadingTutores, setLoadingTutores] = useState(false);
  const [paginaTutores, setPaginaTutores] = useState(1);
  const [totalTutores, setTotalTutores] = useState(0);
  const [paginasTotalesTutores, setPaginasTotalesTutores] = useState(1);

  // Ficha Tutor
  const [tutorSeleccionado, setTutorSeleccionado] = useState<Tutor | null>(null);
  const [tutorFichaEditable, setTutorFichaEditable] = useState<Partial<Tutor>>({});
  
  const [gruposData, setGruposData] = useState<any[]>([]);

  // Ficha Alumno - Tabs data
  const [padresAlumno, setPadresAlumno] = useState<any[]>([]);
  const [estadoCuentaAlumno, setEstadoCuentaAlumno] = useState<any[]>([]);
  const [historialPagosAlumno, setHistorialPagosAlumno] = useState<any[]>([]);
  const [calificacionesAlumno, setCalificacionesAlumno] = useState<any[]>([]);
  const [calificacionesExtra, setCalificacionesExtra] = useState<any[]>([]);
  
  // Planes
  const [planPreview, setPlanPreview] = useState<any>(null);
  const [mesesPlanSeleccionado, setMesesPlanSeleccionado] = useState<number | null>(null);
  const [loadingPlan, setLoadingPlan] = useState(false);

  // Vincular tutor modal
  const [modalVincularTutor, setModalVincularTutor] = useState(false);
  const [busquedaVincularTutor, setBusquedaVincularTutor] = useState('');
  const [tutoresParaVincular, setTutoresParaVincular] = useState<Tutor[]>([]);

  // Nuevo Alumno modal
  const [modalNuevoAlumno, setModalNuevoAlumno] = useState(false);
  const [erroresNuevoAlumno, setErroresNuevoAlumno] = useState<Record<string, string>>({});
  const [nuevoAlumnoData, setNuevoAlumnoData] = useState<any>({ nombrePila: '', paterno: '', materno: '', genero: '', fechaNacimiento: '', estadoNacimiento: '', ciudadNacimiento: '', matricula: '', curp: '', nivel: '', grado: '', seccion: '', estado: 'Activo', planPagoMeses: '' });

  const nivelesDisponibles = ['PREESCOLAR', 'PRIMARIA', 'SECUNDARIA', 'BACHILLERATO'];

  const cargarEstadoCuenta = async () => {
    if (!alumnoFichaEditable?.id) return;
    try {
      const res: any = await api.get(`/alumnos/${alumnoFichaEditable.id}/estado-cuenta`);
      setEstadoCuentaAlumno(res.data || res);
    } catch (err) {
      console.error(err);
    }
  };

  const previsualizarPlan = async (meses: number) => {
    if (!alumnoFichaEditable?.id) return;
    setLoadingPlan(true);
    setMesesPlanSeleccionado(meses);
    try {
      const res: any = await api.get(`/alumnos/${alumnoFichaEditable.id}/planes/preview?meses=${meses}`);
      setPlanPreview(res.data || res);
    } catch (err: any) {
      alert(err.response?.data?.message || 'Error al previsualizar plan.');
      setPlanPreview(null);
      setMesesPlanSeleccionado(null);
    } finally {
      setLoadingPlan(false);
    }
  };

  const asignarPlan = async () => {
    if (!alumnoFichaEditable?.id || !mesesPlanSeleccionado) return;
    if (!window.confirm(`¿Estás seguro de asignar el plan de ${mesesPlanSeleccionado} meses?`)) return;
    try {
      await api.post(`/alumnos/${alumnoFichaEditable.id}/planes`, { meses: mesesPlanSeleccionado });
      alert('Plan asignado correctamente.');
      setPlanPreview(null);
      setMesesPlanSeleccionado(null);
      setAlumnoSeleccionado((prev: any) => ({
        ...prev,
        planPago: { nombre: `Plan de ${mesesPlanSeleccionado} Meses` }
      }));
      // Recargar cuenta
      cargarEstadoCuenta();
    } catch (err: any) {
      alert(err.response?.data?.message || 'Error al asignar el plan.');
    }
  };

  const resetearPlan = async () => {
    if (!alumnoFichaEditable?.id) return;
    if (!window.confirm('¿Estás seguro de eliminar el plan actual? Se borrarán todos los cargos pendientes. Los cargos pagados no se pueden eliminar.')) return;
    try {
      await api.delete(`/alumnos/${alumnoFichaEditable.id}/planes`);
      alert('Plan reseteado correctamente.');
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

  const abrirFicha = async (al: any) => {
    setAlumnoSeleccionado(al);
    setAlumnoFichaEditable({ 
      ...al,
      nivel: al.grupo?.nivel || al.nivel || '',
      grado: al.grupo?.grado || al.grado || '',
      seccion: al.grupo?.seccion || al.seccion || ''
    });
    setTabAlumnoFicha('academicos');
    setPadresAlumno(al.padres || al.padresLista || []);
    setEstadoCuentaAlumno([]);
    setHistorialPagosAlumno([]);
    setCalificacionesAlumno([]);
    setCalificacionesExtra([]);
    // Load full alumno data with relations
    try {
      const full = await alumnosService.getAlumnoById(al.id || al.alumnoId as number);
      if (full) {
        setPadresAlumno(full.padres || full.padresLista || []);
        setAlumnoSeleccionado((prev: any) => ({ ...prev, ...full }));
      }
    } catch (e) { console.error(e); }
  };

  const handleGuardarFicha = async () => {
    try {
      const payload = { ...alumnoFichaEditable };
      if (payload.nivel && payload.grado && payload.seccion) {
        const grupoMatch = gruposData.find((g: any) => g.nivel === payload.nivel && String(g.grado) === String(payload.grado) && g.seccion === payload.seccion);
        if (grupoMatch) payload.grupoId = grupoMatch.grupoId || grupoMatch.id;
      }
      await alumnosService.updateAlumno(payload.id || payload.alumnoId as number, payload);
      alert('Información actualizada correctamente');
      cargarAlumnos();
      // Update local state to reflect changes
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

  // === Vinculación Tutor ===
  const buscarTutorParaVincular = async () => {
    if (busquedaVincularTutor.length < 2) { setTutoresParaVincular([]); return; }
    try {
      const data = await tutoresService.getTutores({ q: busquedaVincularTutor, limit: 5 });
      if (data) setTutoresParaVincular(data as Tutor[]);
    } catch (e) { console.error(e); setTutoresParaVincular([]); }
  };

  const confirmarVinculacionTutor = async (tutor: any) => {
    try {
      await tutoresService.vincularAlumno(tutor.tutorId || tutor.id as number, {
        alumnoId: alumnoSeleccionado?.id || alumnoSeleccionado.alumnoId as number, tipoRelacion: 'tutor', esResponsableFinanciero: false, puedeRecoger: true
      });
      alert('Tutor vinculado correctamente');
      setModalVincularTutor(false);
      setBusquedaVincularTutor('');
      abrirFicha(alumnoSeleccionado);
    } catch (e: any) { alert(e?.response?.data?.message || 'Error al vincular tutor'); }
  };

  const desvincularTutor = async (tutorId: number) => {
    if (!confirm('¿Seguro que deseas desvincular este tutor del alumno?')) return;
    try {
      await api.delete(`/tutores/${tutorId}/desvincular/${alumnoSeleccionado?.id}`);
      alert('Tutor desvinculado');
      abrirFicha(alumnoSeleccionado);
    } catch (e: any) { alert(e?.response?.data?.message || 'Error al desvincular'); }
  };

  // === Estado de Cuenta y Historial de Pagos ===
  const cargarPagosAlumnoFicha = async () => {
    if (!alumnoSeleccionado) return;
    try {
      const resCal = await api.get('/pagos/calendario', { params: { alumnoId: alumnoSeleccionado?.id } });
      if (resCal.data) setEstadoCuentaAlumno(resCal.data);
    } catch (e) { console.error(e); }
    try {
      const resPagos = await api.get('/pagos', { params: { alumnoId: alumnoSeleccionado?.id } });
      if (resPagos.data) setHistorialPagosAlumno(resPagos.data);
    } catch (e) { console.error(e); }
  };

  // === Calificaciones (Boleta) ===
  const cargarCalificacionesAlumno = async () => {
    if (!alumnoSeleccionado) return;
    try {
      const res = await api.get(`/calificaciones/alumno/${alumnoSeleccionado?.id}`);
      if (res.data) {
        const todas = Array.isArray(res.data) ? res.data : (res.data.calificaciones || res.data.data || []);
        
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
      }
    } catch (e) { console.error(e); }
  };

  const abrirFichaTutor = (tutor: any) => {
    setTutorSeleccionado(tutor);
    setTutorFichaEditable({ ...tutor });
  };

  const handleGuardarFichaTutor = async () => {
    try {
      await tutoresService.updateTutor(tutorFichaEditable.id || tutorFichaEditable.tutorId as number, tutorFichaEditable);
      alert('Tutor actualizado correctamente');
      cargarTutores();
      setTutorSeleccionado({ ...tutorFichaEditable });
    } catch (error) {
      console.error('Error actualizando tutor', error);
      alert('Error al guardar tutor');
    }
  };

  
  useEffect(() => {
    if (modalNuevoAlumno) {
      const d = nuevoAlumnoData;
      if (d.nombrePila && d.paterno && d.fechaNacimiento && d.genero && d.estadoNacimiento) {
        const generated = generateCURP(d.nombrePila, d.paterno, d.materno || '', d.fechaNacimiento, d.genero as 'H' | 'M', d.estadoNacimiento);
        if (generated && !d.curp?.match(/^[A-Z]{4}[0-9]{6}[H,M][A-Z]{5}[0-9A-Z]{2}$/)) {
           // We only auto-fill if the user hasn't typed a full valid CURP manually
           if (d.curp?.length < 16 || generated.startsWith(d.curp?.substring(0, 16))) {
             setNuevoAlumnoData((prev: any) => ({ ...prev, curp: generated }));
           }
        }
      }
    }
  }, [nuevoAlumnoData.nombrePila, nuevoAlumnoData.paterno, nuevoAlumnoData.materno, nuevoAlumnoData.fechaNacimiento, nuevoAlumnoData.genero, nuevoAlumnoData.estadoNacimiento, modalNuevoAlumno]);


  const handleGuardarNuevoAlumno = async () => {
    // Validacion
    const errores: Record<string, string> = {};
    if (!nuevoAlumnoData.nombrePila?.trim()) errores.nombrePila = 'Requerido. Ej: Luis Angel';
    if (!nuevoAlumnoData.paterno?.trim()) errores.paterno = 'Requerido. Ej: Reyes';
    if (!nuevoAlumnoData.matricula?.trim()) errores.matricula = 'Requerido. Ej: MAT-2023-01';
    
    if (nuevoAlumnoData.estadoNacimiento !== 'Extranjero') {
      if (!nuevoAlumnoData.curp?.trim() || nuevoAlumnoData.curp.length !== 18) errores.curp = 'CURP debe tener 18 caracteres';
    } else {
      if (nuevoAlumnoData.curp && nuevoAlumnoData.curp.trim().length > 0 && nuevoAlumnoData.curp.length < 16) {
        errores.curp = 'Si se ingresa, deben ser al menos 16 caracteres';
      }
    }
    
    if (!nuevoAlumnoData.nivel) errores.nivel = 'Requerido';
    if (!nuevoAlumnoData.grado) errores.grado = 'Requerido';
    if (!nuevoAlumnoData.seccion) errores.seccion = 'Requerido';

    if (Object.keys(errores).length > 0) {
      setErroresNuevoAlumno(errores);
      return;
    }

    try {
      const payload = {
        ...nuevoAlumnoData,
        nombre: `${nuevoAlumnoData.nombrePila} ${nuevoAlumnoData.paterno} ${nuevoAlumnoData.materno || ''}`.trim(),
        fechaNacimiento: nuevoAlumnoData.fechaNacimiento ? new Date(nuevoAlumnoData.fechaNacimiento).toISOString() : undefined,
        lugarNacimiento: [nuevoAlumnoData.ciudadNacimiento, nuevoAlumnoData.estadoNacimiento].filter(Boolean).join(', '),
      };
      
      if (payload.nivel && payload.grado && payload.seccion) {
        const grupoMatch = gruposData.find((g: any) => g.nivel === payload.nivel && String(g.grado) === String(payload.grado) && g.seccion === payload.seccion);
        if (grupoMatch) payload.grupoId = grupoMatch.grupoId || grupoMatch.id;
      }
      
      const creado: any = await alumnosService.createAlumno(payload);
      
      if (nuevoAlumnoData.planPagoMeses && payload.grupoId) {
        try {
          const idCreado = creado.id || creado.alumnoId || creado.data?.id || creado.data?.alumnoId;
          if (idCreado) {
            await api.post(`/alumnos/${idCreado}/planes`, { meses: Number(nuevoAlumnoData.planPagoMeses) });
          }
        } catch (planError) {
          console.error("Error al asignar plan de pago al alumno", planError);
        }
      }

      alert('Alumno registrado correctamente');
      setModalNuevoAlumno(false);
      setNuevoAlumnoData({ nombrePila: '', paterno: '', materno: '', genero: '', fechaNacimiento: '', estadoNacimiento: '', ciudadNacimiento: '', matricula: '', curp: '', nivel: '', grado: '', seccion: '', estado: 'Activo', planPagoMeses: '' });
      setErroresNuevoAlumno({});
      cargarAlumnos();
    } catch (e: any) { 
      if (e?.response?.data?.errors) {
        const backendErrors: Record<string, string> = {};
        e.response.data.errors.forEach((err: any) => {
          // Map backend 'nombre' error to 'nombrePila' so it shows up in the UI
          const campo = err.campo === 'nombre' ? 'nombrePila' : err.campo;
          backendErrors[campo] = err.mensaje;
        });
        setErroresNuevoAlumno(backendErrors);
      } else {
        alert(e?.response?.data?.message || 'Error al registrar alumno'); 
      }
    }
  };

  const handleExportar = () => {
    const dataToExport = tabDirectorio === 'alumnos' ? alumnos : tutores;
    if (dataToExport.length === 0) {
      alert('No hay datos para exportar');
      return;
    }

    const headers = tabDirectorio === 'alumnos' 
      ? ['ID', 'Nombre', 'Matrícula', 'CURP', 'Nivel', 'Grado', 'Estado']
      : ['ID', 'Nombre', 'RFC', 'Correo', 'Teléfono'];
    
    const rows = dataToExport.map((item: any) => {
      if (tabDirectorio === 'alumnos') {
        return [item.id, item.nombre, item.matricula, item.curp, item.nivel, item.grado, item.estado];
      } else {
        return [item.id || item.tutorId, item.nombreCompleto, item.rfc, item.correoElectronico, item.telefono];
      }
    });

    const csvContent = [headers.join(','), ...rows.map(r => r.map(c => `"${c || ''}"`).join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `exportacion_${tabDirectorio}_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleRegistrarPago = () => {
    if (alumnoSeleccionado) {
      const id = alumnoSeleccionado.id || alumnoSeleccionado.alumnoId;
      navigate(`/pagos?alumnoId=${id}`);
    }
  };

  const cargarGrupos = async () => {
    try {
      const res = await api.get('/grupos', { params: { limit: 1000, todos: true } });
      if (res.data) setGruposData(res.data.data || res.data); // Handle pagination object or direct array
    } catch (error) {
      console.error('Error cargando grupos', error);
    }
  };

  useEffect(() => {
    cargarGrupos();
  }, []);

  const cargarAlumnos = async () => {
    setLoading(true);
    try {
      const params: any = { page: pagina, limit: 20, q: busqueda };
      if (filtroEstado && filtroEstado !== 'Todos') params.estado = filtroEstado;
      if (filtroNivel) params.nivel = filtroNivel;
      if (filtroGrado) params.grado = filtroGrado;
      if (filtroSeccion) params.seccion = filtroSeccion;

      const res = await api.get('/alumnos', { params });
      
      if (res.data) {
        const lista = res.data.data || res.data;
        setAlumnos(Array.isArray(lista) ? lista : []);
        setTotal((res as any).pagination?.totalItems || (res as any).pagination?.total || lista.length || 0);
        setPaginasTotales((res as any).pagination?.pages || (res as any).pagination?.totalPages || 1);
      }
    } catch (error) {
      console.error('Error cargando alumnos', error);
    } finally {
      setLoading(false);
    }
  };

  const cargarTutores = async () => {
    setLoadingTutores(true);
    try {
      // api interceptor already returns response.data, so 'res' IS the body {ok, data, pagination}
      const res: any = await api.get('/tutores', { params: { page: paginaTutores, limit: 20, q: busqueda } });
      // Handle both paginated {data:[...], pagination:{...}} and plain array responses
      const lista = Array.isArray(res) ? res : (res.data || []);
      setTutores(Array.isArray(lista) ? lista : []);
      if (res.pagination) {
        setTotalTutores(res.pagination.total || lista.length || 0);
        setPaginasTotalesTutores(res.pagination.pages || 1);
      } else {
        setTotalTutores(lista.length || 0);
        setPaginasTotalesTutores(1);
      }
    } catch (error) {
      console.error('Error cargando tutores', error);
      setTutores([]);
    } finally {
      setLoadingTutores(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      if (tabDirectorio === 'alumnos') {
        cargarAlumnos();
      } else {
        cargarTutores();
      }
    }, 400); // Debounce
    return () => clearTimeout(timer);
  }, [busqueda, filtroEstado, filtroNivel, filtroGrado, filtroSeccion, pagina, paginaTutores, tabDirectorio]);

  // Dynamically compute available grades and groups based on existing data
  const gruposArray = Array.isArray(gruposData) ? gruposData : [];
  const gradosDisponiblesFiltro = Array.from(new Set(gruposArray.filter(g => g.nivel?.toUpperCase() === filtroNivel?.toUpperCase()).map(g => g.grado))).sort();
  const seccionesDisponiblesFiltro = Array.from(new Set(gruposArray.filter(g => g.nivel?.toUpperCase() === filtroNivel?.toUpperCase() && g.grado == filtroGrado).map(g => g.seccion))).sort();
  
  const gradosDisponiblesEdit = Array.from(new Set(gruposArray.filter(g => g.nivel?.toUpperCase() === (alumnoFichaEditable.nivel as string)?.toUpperCase()).map(g => g.grado))).sort();
  const seccionesDisponiblesEdit = Array.from(new Set(gruposArray.filter(g => g.nivel?.toUpperCase() === (alumnoFichaEditable.nivel as string)?.toUpperCase() && g.grado == alumnoFichaEditable.grado).map(g => g.seccion))).sort();

  return (
    <div className="h-full flex flex-col">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold text-navy-800">Directorio Escolar</h2>
        <div className="flex gap-3">
          <button className="flex items-center gap-2 px-4 py-2 border border-gray-200 rounded-xl text-gray-700 hover:bg-gray-50 transition-colors">
            <Upload size={16} /> Importar CSV
          </button>
          <button className="flex items-center gap-2 px-4 py-2 bg-navy-600 text-white rounded-xl hover:bg-navy-700 transition-colors shadow-sm font-medium" onClick={() => setModalNuevoAlumno(true)}>
            <UserPlus size={16} /> Nuevo alumno
          </button>
        </div>
      </div>

      {tabDirectorio === 'alumnos' && (
        <>
        <div className="flex flex-wrap gap-3 mb-6 items-center">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
          <input 
            type="text" 
            placeholder="Buscar alumno, matrícula..." 
            className="pl-9 pr-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none w-72"
            value={busqueda}
            onChange={(e) => setBusqueda(e.target.value)}
          />
        </div>
        
        <select 
          className="px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
          value={filtroEstado}
          onChange={(e) => setFiltroEstado(e.target.value)}
        >
          <option value="">Activos</option>
          <option value="Todos">Todos</option>
          <option value="Baja Temporal">Baja Temporal</option>
          <option value="Baja Definitiva">Baja Definitiva</option>
          <option value="Egresado">Egresado</option>
        </select>

        <select 
          className="px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
          value={filtroNivel}
          onChange={(e) => {
            setFiltroNivel(e.target.value);
            setFiltroGrado('');
            setFiltroSeccion('');
          }}
        >
          <option value="">Todos los niveles</option>
          {nivelesDisponibles.map(n => <option key={n} value={n}>{n}</option>)}
        </select>

        <select 
          className="px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none w-28"
          value={filtroGrado}
          onChange={(e) => {
            setFiltroGrado(e.target.value);
            setFiltroSeccion('');
          }}
          disabled={!filtroNivel}
        >
          <option value="">Grado</option>
          {gradosDisponiblesFiltro.map(g => (
            <option key={g} value={g}>{g}°</option>
          ))}
        </select>

        <select 
          className="px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none w-32"
          value={filtroSeccion}
          onChange={(e) => setFiltroSeccion(e.target.value)}
          disabled={!filtroGrado}
        >
          <option value="">Grupo</option>
          {seccionesDisponiblesFiltro.map(s => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>

        <div className="ml-auto flex items-center gap-3">
          <span className="bg-navy-50 text-navy-700 px-3 py-1 rounded-full text-sm font-medium">
            Resultados: {total}
          </span>
          <button className="flex items-center gap-2 px-3 py-1.5 border border-gray-200 rounded-lg text-gray-600 hover:bg-gray-50 text-sm">
            <Download size={14} /> Exportar
          </button>
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 overflow-hidden flex flex-col">
        <div className="overflow-x-auto flex-1">
          <table className="w-full text-sm text-left">
            <thead className="bg-gray-50 border-b border-gray-100 text-gray-600">
              <tr>
                <th className="px-6 py-4 font-semibold">Alumno</th>
                <th className="px-6 py-4 font-semibold">Grupo/Nivel</th>
                <th className="px-6 py-4 font-semibold">Tutor Principal</th>
                <th className="px-6 py-4 font-semibold">Contacto</th>
                <th className="px-6 py-4 font-semibold text-right">Acciones</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={5} className="px-6 py-10 text-center text-gray-400">
                    Cargando alumnos...
                  </td>
                </tr>
              ) : alumnos.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-10 text-center text-gray-400">
                    No se encontraron alumnos.
                  </td>
                </tr>
              ) : (
                alumnos.map((al) => {
                  const tutorPrincipal = al.padres && al.padres.length > 0 ? al.padres[0] : null;
                  return (
                    <tr key={al.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                      <td className="px-6 py-4">
                        <div className="font-medium text-gray-900">{al.nombre}</div>
                        <div className="text-xs text-gray-500">Matrícula: {al.matricula}</div>
                      </td>
                      <td className="px-6 py-4 text-gray-600">{(al as any).grupo?.nombre || (al.nivel + ' ' + (al.grado || ''))}</td>
                      <td className="px-6 py-4 text-gray-600">{tutorPrincipal?.nombre || 'Sin asignar'}</td>
                      <td className="px-6 py-4 text-xs text-gray-500">
                        <div>Tel: {tutorPrincipal?.telefono || '-'}</div>
                        {tutorPrincipal?.email && <div>{tutorPrincipal.email}</div>}
                      </td>
                      <td className="px-6 py-4 text-right">
                        <button 
                          onClick={() => abrirFicha(al)}
                          className="px-3 py-1.5 text-xs font-medium text-navy-600 bg-navy-50 rounded-lg hover:bg-navy-100 transition-colors"
                        >
                          Ver expediente
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
        
        {paginasTotales > 1 && (
          <div className="flex items-center justify-between py-3 px-6 border-t border-gray-100 bg-gray-50/50">
            <span className="text-sm text-gray-500">
              Página {pagina} de {paginasTotales} &middot; {total} resultados
            </span>
            <div className="flex gap-2">
              <button 
                className="px-3 py-1.5 border border-gray-200 bg-white rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                disabled={pagina <= 1}
                onClick={() => setPagina(p => p - 1)}
              >
                Anterior
              </button>
              <button 
                className="px-3 py-1.5 border border-gray-200 bg-white rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                disabled={pagina >= paginasTotales}
                onClick={() => setPagina(p => p + 1)}
              >
                Siguiente
              </button>
            </div>
          </div>
        )}
      </div>
      </>
      )}

      {tabDirectorio === 'tutores' && (
        <>
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 overflow-hidden flex flex-col mt-4">
            <div className="overflow-x-auto flex-1">
              <table className="w-full text-sm text-left">
                <thead className="bg-gray-50 border-b border-gray-100 text-gray-600">
                  <tr>
                    <th className="px-6 py-4 font-semibold">Tutor / Contacto</th>
                    <th className="px-6 py-4 font-semibold">Alumnos Vinculados</th>
                    <th className="px-6 py-4 font-semibold">Estado</th>
                    <th className="px-6 py-4 font-semibold text-right">Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  {loadingTutores ? (
                    <tr><td colSpan={4} className="px-6 py-10 text-center text-gray-400">Cargando tutores...</td></tr>
                  ) : tutores.length === 0 ? (
                    <tr><td colSpan={4} className="px-6 py-10 text-center text-gray-400">No se encontraron tutores.</td></tr>
                  ) : tutores.map(tutor => (
                    <tr key={tutor.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                      <td className="px-6 py-4">
                        <div className="font-medium text-gray-900">{tutor.nombreCompleto || 'Sin nombre'}</div>
                        <div className="text-xs text-gray-500">{tutor.correoElectronico || 'Sin correo'} &middot; {tutor.telefono || 'Sin teléfono'}</div>
                      </td>
                      <td className="px-6 py-4">
                        {tutor.alumnos && tutor.alumnos.length > 0 ? (
                          <div className="text-gray-600 text-xs">
                            {tutor.alumnos.map((al: any) => al.nombre).join(', ')}
                          </div>
                        ) : (
                          <span className="text-gray-400 text-xs">Ninguno</span>
                        )}
                      </td>
                      <td className="px-6 py-4">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${tutor.activo ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                          {tutor.activo ? 'Activo' : 'Inactivo'}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-right">
                        <button 
                          onClick={() => abrirFichaTutor(tutor)}
                          className="px-3 py-1.5 text-xs font-medium text-navy-600 bg-navy-50 rounded-lg hover:bg-navy-100 transition-colors"
                        >
                          Ver ficha
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {paginasTotalesTutores > 1 && (
              <div className="flex items-center justify-between py-3 px-6 border-t border-gray-100 bg-gray-50/50">
                <span className="text-sm text-gray-500">
                  Página {paginaTutores} de {paginasTotalesTutores} &middot; {totalTutores} resultados
                </span>
                <div className="flex gap-2">
                  <button 
                    className="px-3 py-1.5 border border-gray-200 bg-white rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    disabled={paginaTutores <= 1}
                    onClick={() => setPaginaTutores(p => p - 1)}
                  >
                    Anterior
                  </button>
                  <button 
                    className="px-3 py-1.5 border border-gray-200 bg-white rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    disabled={paginaTutores >= paginasTotalesTutores}
                    onClick={() => setPaginaTutores(p => p + 1)}
                  >
                    Siguiente
                  </button>
                </div>
              </div>
            )}
          </div>
        </>
      )}

      {/* Slide-over (Panel lateral) para Expediente Tutor */}
      <div className={`fixed inset-y-0 right-0 w-full max-w-4xl bg-white shadow-2xl transform transition-transform duration-300 ease-in-out z-40 border-l border-gray-200 ${tutorSeleccionado ? 'translate-x-0' : 'translate-x-full'}`}>
        {tutorSeleccionado && (
          <div className="h-full flex flex-col">
            <div className="p-6 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h3 className="font-bold text-lg text-navy-800">Ficha del Tutor</h3>
              <button 
                onClick={() => setTutorSeleccionado(null)}
                className="p-2 hover:bg-gray-200 rounded-full transition-colors"
              >
                <X size={20} className="text-gray-500" />
              </button>
            </div>
            
            <div className="flex-1 overflow-y-auto bg-gray-50/30 p-6">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="md:col-span-1">
                  <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 text-center">
                    <div className="w-24 h-24 bg-navy-100 text-navy-600 rounded-full flex items-center justify-center mx-auto mb-4 text-3xl font-bold">
                      {tutorSeleccionado?.nombre?.charAt(0)}
                    </div>
                    <h3 className="font-bold text-lg text-gray-900">{tutorSeleccionado?.nombre} {tutorSeleccionado?.apellidos}</h3>
                    <span className={`inline-block mt-2 px-3 py-1 rounded-full text-xs font-medium border ${tutorSeleccionado?.activo ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
                      {tutorSeleccionado?.activo ? 'Tutor Activo' : 'Tutor Inactivo'}
                    </span>
                  </div>
                </div>

                <div className="md:col-span-2">
                  <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <div className="flex border-b border-gray-100">
                      <button className="px-6 py-3 text-sm font-semibold text-navy-700 border-b-2 border-navy-700 bg-gray-50/50">
                        Información General
                      </button>
                    </div>

                    <div className="p-6">
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">Nombre(s)</label>
                          <input 
                            type="text" 
                            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                            value={tutorFichaEditable.nombre || ''}
                            onChange={(e) => setTutorFichaEditable({...tutorFichaEditable, nombre: e.target.value})}
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">Apellidos</label>
                          <input 
                            type="text" 
                            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                            value={tutorFichaEditable.apellidos || ''}
                            onChange={(e) => setTutorFichaEditable({...tutorFichaEditable, apellidos: e.target.value})}
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">Teléfono</label>
                          <input 
                            type="text" 
                            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                            value={tutorFichaEditable.telefono || ''}
                            onChange={(e) => setTutorFichaEditable({...tutorFichaEditable, telefono: e.target.value})}
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">Correo Electrónico</label>
                          <input 
                            type="email" 
                            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                            value={tutorFichaEditable.email || ''}
                            onChange={(e) => setTutorFichaEditable({...tutorFichaEditable, email: e.target.value})}
                          />
                        </div>
                        <div className="col-span-2">
                          <label className="block text-sm font-medium text-gray-700 mb-1">Estado</label>
                          <select 
                            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                            value={tutorFichaEditable.activo ? 'true' : 'false'}
                            onChange={(e) => setTutorFichaEditable({...tutorFichaEditable, activo: e.target.value === 'true'})}
                          >
                            <option value="true">Activo</option>
                            <option value="false">Inactivo</option>
                          </select>
                        </div>
                      </div>

                      <div className="mt-8 flex justify-end gap-3">
                        <button 
                          onClick={handleGuardarFichaTutor}
                          className="px-6 py-2 bg-navy-800 text-white rounded-xl hover:bg-navy-900 font-medium shadow-sm transition-colors"
                        >
                          Guardar Ficha
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Slide-over (Panel lateral) para Expediente */}
      <div className={`fixed inset-y-0 right-0 w-full max-w-4xl bg-white shadow-2xl transform transition-transform duration-300 ease-in-out z-40 border-l border-gray-200 ${alumnoSeleccionado ? 'translate-x-0' : 'translate-x-full'}`}>
        {alumnoSeleccionado && (
          <div className="h-full flex flex-col">
            <div className="p-6 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h3 className="font-bold text-lg text-navy-800">Expediente del Alumno</h3>
              <button onClick={() => setAlumnoSeleccionado(null)} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 flex-1 overflow-y-auto flex gap-6">
              {/* Left Column: Profile Card */}
              <div className="w-1/3">
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
                    <button className="w-full px-4 py-2 bg-navy-600 text-white rounded-xl hover:bg-navy-700 font-medium" onClick={handleRegistrarPago}>
                      Registrar Pago
                    </button>
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
              <div className="w-2/3 flex flex-col">
                <div className="sticky top-0 bg-white z-10 pt-2 pb-0 mb-6 border-b">
                  <div className="flex overflow-x-auto whitespace-nowrap">
                  <button 
                    className={`px-4 py-3 text-sm font-medium ${tabAlumnoFicha === 'academicos' ? 'text-navy-700 border-b-2 border-navy-700' : 'text-gray-500'}`}
                    onClick={() => setTabAlumnoFicha('academicos')}
                  >
                    Info Escolar
                  </button>
                  <button 
                    className={`px-4 py-3 text-sm font-medium flex items-center gap-2 ${tabAlumnoFicha === 'tutores' ? 'text-navy-700 border-b-2 border-navy-700' : 'text-gray-500'}`}
                    onClick={() => setTabAlumnoFicha('tutores')}
                  >
                    <Users size={16} /> Familia
                  </button>
                  <button 
                    className={`px-4 py-3 text-sm font-medium flex items-center gap-2 ${tabAlumnoFicha === 'planes' ? 'text-navy-700 border-b-2 border-navy-700' : 'text-gray-500'}`}
                    onClick={() => setTabAlumnoFicha('planes')}
                  >
                    <Calendar size={16} /> Plan de Pago
                  </button>
                  <button 
                    className={`px-4 py-3 text-sm font-medium flex items-center gap-2 ${tabAlumnoFicha === 'estado_cuenta' ? 'text-navy-700 border-b-2 border-navy-700' : 'text-gray-500'}`}
                    onClick={() => { setTabAlumnoFicha('estado_cuenta'); cargarPagosAlumnoFicha(); }}
                  >
                    <Clock size={16} /> Estado de Cuenta
                  </button>
                  <button 
                    className={`px-4 py-3 text-sm font-medium flex items-center gap-2 ${tabAlumnoFicha === 'historial_pagos' ? 'text-navy-700 border-b-2 border-navy-700' : 'text-gray-500'}`}
                    onClick={() => { setTabAlumnoFicha('historial_pagos'); cargarPagosAlumnoFicha(); }}
                  >
                    <Receipt size={16} /> Historial Pagos
                  </button>
                  <button 
                    className={`px-4 py-3 text-sm font-medium flex items-center gap-2 ${tabAlumnoFicha === 'calificaciones' ? 'text-navy-700 border-b-2 border-navy-700' : 'text-gray-500'}`}
                    onClick={() => { setTabAlumnoFicha('calificaciones'); cargarCalificacionesAlumno(); }}
                  >
                    <GraduationCap size={16} /> Calificaciones
                  </button>
                  </div>
                </div>

                <div className="flex-1">
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
                      <div className="pt-4 flex justify-between items-center">
                        <button 
                          type="button"
                          onClick={() => {
                            setAlumnoFichaEditable({...alumnoFichaEditable, estado: 'Baja Temporal'});
                          }}
                          className="px-6 py-2 border border-yellow-400 text-yellow-600 bg-white rounded-xl hover:bg-yellow-50 font-medium transition-colors"
                        >
                          Dar Baja Temporal
                        </button>
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
                          <div key={idx} className="border rounded-xl p-4 flex justify-between items-center">
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
                              onKeyUp={() => buscarTutorParaVincular()}
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
                      {estadoCuentaAlumno.length > 0 ? (
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
                              
                              <div className="overflow-x-auto border border-gray-100 rounded-xl">
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
                        <div className="overflow-x-auto border border-gray-100 rounded-xl">
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
                                      <span className="text-xs text-blue-600 font-medium">PDF</span>
                                    ) : (
                                      <span className="text-xs text-gray-400">-</span>
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
                              <div className="overflow-x-auto border border-gray-100 rounded-xl mb-6">
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
                              <div className="overflow-x-auto border border-gray-100 rounded-xl">
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
        )}
      </div>

      {/* Modal Nuevo Alumno */}
      {modalNuevoAlumno && (
        <div className="fixed inset-0 bg-black/30 z-50 flex items-center justify-center" onClick={() => setModalNuevoAlumno(false)}>
          <div className="bg-white rounded-2xl p-6 w-full max-w-lg shadow-2xl" onClick={e => e.stopPropagation()}>
            <h3 className="font-bold text-lg text-navy-800 mb-4">Registrar Nuevo Alumno</h3>
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Nombre(s) <span className="text-red-500">*</span></label>
                  <input 
                    type="text"
                    className={`w-full px-4 py-2 rounded-xl border focus:ring-2 outline-none uppercase ${erroresNuevoAlumno.nombrePila ? 'border-red-500 focus:ring-red-500' : 'border-gray-200 focus:ring-navy-500'}`} 
                    value={nuevoAlumnoData.nombrePila}
                    onChange={(e) => {
                      setNuevoAlumnoData({...nuevoAlumnoData, nombrePila: e.target.value.toUpperCase()});
                      if (erroresNuevoAlumno.nombrePila) setErroresNuevoAlumno({...erroresNuevoAlumno, nombrePila: ''});
                    }}
                  />
                  {erroresNuevoAlumno.nombrePila && <p className="text-red-500 text-xs mt-1">{erroresNuevoAlumno.nombrePila}</p>}
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Apellido Paterno <span className="text-red-500">*</span></label>
                  <input 
                    type="text"
                    className={`w-full px-4 py-2 rounded-xl border focus:ring-2 outline-none uppercase ${erroresNuevoAlumno.paterno ? 'border-red-500 focus:ring-red-500' : 'border-gray-200 focus:ring-navy-500'}`} 
                    value={nuevoAlumnoData.paterno}
                    onChange={(e) => {
                      setNuevoAlumnoData({...nuevoAlumnoData, paterno: e.target.value.toUpperCase()});
                      if (erroresNuevoAlumno.paterno) setErroresNuevoAlumno({...erroresNuevoAlumno, paterno: ''});
                    }}
                  />
                  {erroresNuevoAlumno.paterno && <p className="text-red-500 text-xs mt-1">{erroresNuevoAlumno.paterno}</p>}
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Apellido Materno</label>
                  <input 
                    type="text"
                    className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none uppercase" 
                    value={nuevoAlumnoData.materno}
                    onChange={(e) => setNuevoAlumnoData({...nuevoAlumnoData, materno: e.target.value.toUpperCase()})}
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Fecha de Nac.</label>
                  <input 
                    type="date"
                    className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none" 
                    value={nuevoAlumnoData.fechaNacimiento}
                    onChange={(e) => setNuevoAlumnoData({...nuevoAlumnoData, fechaNacimiento: e.target.value})}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Género</label>
                  <select 
                    className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                    value={nuevoAlumnoData.genero}
                    onChange={(e) => setNuevoAlumnoData({...nuevoAlumnoData, genero: e.target.value})}
                  >
                    <option value="">Seleccione</option>
                    <option value="H">Hombre</option>
                    <option value="M">Mujer</option>
                  </select>
                </div>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Lugar de Nac. (Estado)</label>
                  <select 
                    className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                    value={nuevoAlumnoData.estadoNacimiento}
                    onChange={(e) => setNuevoAlumnoData({...nuevoAlumnoData, estadoNacimiento: e.target.value})}
                  >
                    <option value="">Seleccione</option>
                    <option value="Aguascalientes">Aguascalientes</option>
                    <option value="Baja California">Baja California</option>
                    <option value="Baja California Sur">Baja California Sur</option>
                    <option value="Campeche">Campeche</option>
                    <option value="Coahuila">Coahuila</option>
                    <option value="Colima">Colima</option>
                    <option value="Chiapas">Chiapas</option>
                    <option value="Chihuahua">Chihuahua</option>
                    <option value="Ciudad de Mexico">Ciudad de México</option>
                    <option value="Durango">Durango</option>
                    <option value="Guanajuato">Guanajuato</option>
                    <option value="Guerrero">Guerrero</option>
                    <option value="Hidalgo">Hidalgo</option>
                    <option value="Jalisco">Jalisco</option>
                    <option value="Mexico">Estado de México</option>
                    <option value="Michoacan">Michoacán</option>
                    <option value="Morelos">Morelos</option>
                    <option value="Nayarit">Nayarit</option>
                    <option value="Nuevo Leon">Nuevo León</option>
                    <option value="Oaxaca">Oaxaca</option>
                    <option value="Puebla">Puebla</option>
                    <option value="Queretaro">Querétaro</option>
                    <option value="Quintana Roo">Quintana Roo</option>
                    <option value="San Luis Potosi">San Luis Potosí</option>
                    <option value="Sinaloa">Sinaloa</option>
                    <option value="Sonora">Sonora</option>
                    <option value="Tabasco">Tabasco</option>
                    <option value="Tamaulipas">Tamaulipas</option>
                    <option value="Tlaxcala">Tlaxcala</option>
                    <option value="Veracruz">Veracruz</option>
                    <option value="Yucatan">Yucatán</option>
                    <option value="Zacatecas">Zacatecas</option>
                    <option value="Extranjero">Extranjero</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Ciudad / Municipio</label>
                  <input 
                    type="text"
                    className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                    placeholder="Ej. Tijuana, Monterrey..."
                    value={nuevoAlumnoData.ciudadNacimiento}
                    onChange={(e) => setNuevoAlumnoData({...nuevoAlumnoData, ciudadNacimiento: e.target.value})}
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Matrícula <span className="text-red-500">*</span></label>
                  <input 
                    type="text"
                    className={`w-full px-4 py-2 rounded-xl border focus:ring-2 outline-none uppercase ${erroresNuevoAlumno.matricula ? 'border-red-500 focus:ring-red-500' : 'border-gray-200 focus:ring-navy-500'}`} 
                    value={nuevoAlumnoData.matricula}
                    onChange={(e) => {
                      setNuevoAlumnoData({...nuevoAlumnoData, matricula: e.target.value});
                      if (erroresNuevoAlumno.matricula) setErroresNuevoAlumno({...erroresNuevoAlumno, matricula: ''});
                    }}
                  />
                  {erroresNuevoAlumno.matricula && <p className="text-red-500 text-xs mt-1">{erroresNuevoAlumno.matricula}</p>}
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    CURP {nuevoAlumnoData.estadoNacimiento !== 'Extranjero' && <span className="text-red-500">*</span>}
                  </label>
                  <input 
                    type="text"
                    className={`w-full px-4 py-2 rounded-xl border focus:ring-2 outline-none uppercase ${erroresNuevoAlumno.curp ? 'border-red-500 focus:ring-red-500' : 'border-gray-200 focus:ring-navy-500'}`} 
                    value={nuevoAlumnoData.curp}
                    onChange={(e) => {
                      setNuevoAlumnoData({...nuevoAlumnoData, curp: e.target.value.toUpperCase()});
                      if (erroresNuevoAlumno.curp) setErroresNuevoAlumno({...erroresNuevoAlumno, curp: ''});
                    }}
                  />
                  {erroresNuevoAlumno.curp && <p className="text-red-500 text-xs mt-1">{erroresNuevoAlumno.curp}</p>}
                </div>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Nivel <span className="text-red-500">*</span></label>
                  <select 
                    className={`w-full px-4 py-2 rounded-xl border focus:ring-2 outline-none ${erroresNuevoAlumno.nivel ? 'border-red-500 focus:ring-red-500' : 'border-gray-200 focus:ring-navy-500'}`} 
                    value={nuevoAlumnoData.nivel}
                    onChange={(e) => {
                      setNuevoAlumnoData({...nuevoAlumnoData, nivel: e.target.value, grado: '', seccion: ''});
                      if (erroresNuevoAlumno.nivel) setErroresNuevoAlumno({...erroresNuevoAlumno, nivel: ''});
                    }}
                  >
                    <option value="">Selecciona Nivel</option>
                    {nivelesDisponibles.map(n => <option key={n} value={n}>{n}</option>)}
                  </select>
                  {erroresNuevoAlumno.nivel && <p className="text-red-500 text-xs mt-1">{erroresNuevoAlumno.nivel}</p>}
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Grado</label>
                  <select 
                    className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none" 
                    value={nuevoAlumnoData.grado}
                    onChange={(e) => setNuevoAlumnoData({...nuevoAlumnoData, grado: e.target.value})}
                    disabled={!nuevoAlumnoData.nivel}
                  >
                    <option value="">Selecciona Grado</option>
                    {[1,2,3,4,5,6].map(g => <option key={g} value={g}>{g}°</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Sección</label>
                  <select 
                    className={`w-full px-4 py-2 rounded-xl border focus:ring-2 outline-none ${erroresNuevoAlumno.seccion ? 'border-red-500 focus:ring-red-500' : 'border-gray-200 focus:ring-navy-500'}`} 
                    value={nuevoAlumnoData.seccion}
                    onChange={(e) => setNuevoAlumnoData({...nuevoAlumnoData, seccion: e.target.value})}
                    disabled={!nuevoAlumnoData.grado}
                  >
                    <option value="">Selecciona Sección</option>
                    {Array.from(new Set(
                      gruposData
                        .filter(g => g.nivel === nuevoAlumnoData.nivel && String(g.grado) === String(nuevoAlumnoData.grado))
                        .map(g => g.seccion)
                    )).map((s: any) => <option key={s} value={s}>{s}</option>)}
                  </select>
                  {erroresNuevoAlumno.seccion && <p className="text-red-500 text-xs mt-1">{erroresNuevoAlumno.seccion}</p>}
                </div>
              </div>
              
              <div className="border-t pt-4 mt-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">Plan de Pago (Opcional)</label>
                <select 
                  className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none" 
                  value={nuevoAlumnoData.planPagoMeses}
                  onChange={(e) => setNuevoAlumnoData({...nuevoAlumnoData, planPagoMeses: e.target.value})}
                >
                  <option value="">- Sin Plan Asignado Inicialmente -</option>
                  <option value="10">Plan de 10 Meses (Septiembre a Junio)</option>
                  <option value="12">Plan de 12 Meses (Pago doble en Diciembre)</option>
                </select>
                <p className="text-xs text-gray-500 mt-1">El plan se asignará automáticamente al calendario de pagos.</p>
              </div>
            </div>
            <div className="mt-6 flex justify-end gap-3">
              <button className="px-4 py-2 border border-gray-200 rounded-xl text-gray-600 hover:bg-gray-50" onClick={() => setModalNuevoAlumno(false)}>Cancelar</button>
              <button className="px-6 py-2 bg-navy-800 text-white rounded-xl hover:bg-navy-900 shadow-sm" onClick={handleGuardarNuevoAlumno}>Guardar Alumno</button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
