import React, { useState, useEffect } from 'react';
import { Users, BookOpen, Plus, Search, X, Edit, Trash2, UserPlus, ArrowUpCircle } from 'lucide-react';
import api from '../services/api';

import { useAuthStore } from '../store/useAuthStore';

export function Grupos() {
  const { user } = useAuthStore();
  const isAdmin = user?.rol === 'ADMIN' || user?.rol === 'DIRECTOR';

  const [grupos, setGrupos] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [docentes, setDocentes] = useState<any[]>([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [nuevoGrupo, setNuevoGrupo] = useState({
    nombre: '',
    nivel: '',
    grado: '',
    seccion: '',
    titular: '', // ID del docente
    materias: [] as any[]
  });
  const [grupoEditandoId, setGrupoEditandoId] = useState<number | null>(null);
  
  // Clonar Materias state
  const [grupoPlantillaId, setGrupoPlantillaId] = useState('');

  // Autocomplete Docente state
  const [busquedaDocente, setBusquedaDocente] = useState('');
  const [mostrarDropdownDocente, setMostrarDropdownDocente] = useState(false);

  // Alumnos Modal
  const [isAlumnosModalOpen, setIsAlumnosModalOpen] = useState(false);
  const [alumnosGrupo, setAlumnosGrupo] = useState<any[]>([]);
  const [grupoViendoAlumnos, setGrupoViendoAlumnos] = useState<any>(null);

  const [isMateriaModalOpen, setIsMateriaModalOpen] = useState(false);
  const [materiaEditandoInfo, setMateriaEditandoInfo] = useState<{ index: number, grupoId: number } | null>(null);
  const [nuevaMateria, setNuevaMateria] = useState({
    nombre: '',
    tipo: 'curricular',
    nivel: '',
    grado: '',
    seccion: '',
    docente: '',
    horariosDia: [] as { dia: string, inicio: string, fin: string }[],
    aula: ''
  });

  // Asignar Alumnos a Materia
  const [isAsignarAlumnosModalOpen, setIsAsignarAlumnosModalOpen] = useState(false);
  const [materiaActualAsignacion, setMateriaActualAsignacion] = useState<any>(null);
  const [alumnosAsignacionDisponibles, setAlumnosAsignacionDisponibles] = useState<any[]>([]);
  const [alumnosAsignacionSeleccionados, setAlumnosAsignacionSeleccionados] = useState<number[]>([]);
  const [busquedaAsignacion, setBusquedaAsignacion] = useState('');
  
  // Tabs
  const [activeTab, setActiveTab] = useState<'grupos' | 'materias'>('grupos');
  
  // Filters
  const [filtroNivel, setFiltroNivel] = useState('');
  const [filtroGrado, setFiltroGrado] = useState('');
  const [filtroSeccion, setFiltroSeccion] = useState('');

  const nivelesDisponibles = ['PREESCOLAR', 'PRIMARIA', 'SECUNDARIA', 'BACHILLERATO'];
  
  const getGrados = () => {
    if (!filtroNivel) return [];
    if (filtroNivel === 'PREESCOLAR') return ['1', '2', '3'];
    return ['1', '2', '3', '4', '5', '6'];
  };

  const getSecciones = () => {
    if (!filtroNivel || !filtroGrado) return [];
    return ['A', 'B', 'C', 'D', 'E', 'F'];
  };

  const cargarGrupos = async () => {
    setLoading(true);
    try {
      const res = await api.get('/grupos');
      if (res.data) {
        setGrupos(res.data);
      }
    } catch (error) {
      console.error('Error cargando grupos', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    cargarGrupos();
    cargarDocentes();
  }, []);

  const cargarDocentes = async () => {
    try {
      const res = await api.get('/usuarios?rol=MAESTRA');
      if (res.data) setDocentes(res.data);
    } catch (error) {
      console.error('Error cargando docentes', error);
    }
  };

  const handleCrearGrupo = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const payload = {
        nombre: nuevoGrupo.nombre || `${nuevoGrupo.grado}°${nuevoGrupo.seccion} ${nuevoGrupo.nivel}`,
        nivel: nuevoGrupo.nivel,
        grado: nuevoGrupo.grado,
        seccion: nuevoGrupo.seccion,
        titular: nuevoGrupo.titular ? parseInt(nuevoGrupo.titular) : null,
        materias: nuevoGrupo.materias || []
      };

      if (grupoEditandoId) {
        await api.put(`/grupos/${grupoEditandoId}`, payload);
      } else {
        await api.post('/grupos', payload);
      }
      
      setIsModalOpen(false);
      setGrupoEditandoId(null);
      setNuevoGrupo({ nombre: '', nivel: '', grado: '', seccion: '', titular: '', materias: [] });
      cargarGrupos(); // Recargar la lista
    } catch (error) {
      console.error('Error guardando grupo', error);
      alert('Hubo un error al guardar el grupo.');
    }
  };

  const handleEditarGrupo = (grupo: any) => {
    setGrupoEditandoId(grupo.grupoId || grupo.id);
    const docenteTitular = grupo.docenteTitular;
    setNuevoGrupo({
      nombre: grupo.nombre || '',
      nivel: grupo.nivel || '',
      grado: grupo.grado || '',
      seccion: grupo.seccion || '',
      titular: docenteTitular?.usuarioId?.toString() || '',
      materias: grupo.materias || []
    });
    setBusquedaDocente(docenteTitular?.nombreCompleto || '');
    setIsModalOpen(true);
  };

  const handleEliminarGrupo = async (id: number) => {
    if (!window.confirm('¿Estás seguro de eliminar este grupo? Esta acción no se puede deshacer (soft delete).')) return;
    try {
      await api.delete(`/grupos/${id}`);
      cargarGrupos();
    } catch (error) {
      console.error('Error eliminando grupo', error);
      alert('Error al eliminar grupo');
    }
  };

  const handleCargarMateriasPlantilla = () => {
    if (!grupoPlantillaId) return;
    const plantilla = grupos.find(g => (g.id || g.grupoId).toString() === grupoPlantillaId);
    if (plantilla && plantilla.materias) {
      const clonedMaterias = plantilla.materias.map((m: any) => ({
        materia: m.materia || m.nombre,
        tipo: m.tipo || 'curricular',
        horario: m.horario,
        aula: m.aula,
        docente: null // Reset docente
      }));
      setNuevoGrupo(prev => ({ ...prev, materias: clonedMaterias }));
      alert(`Se cargaron ${clonedMaterias.length} materias plantilla.`);
    }
  };

  const handleVerAlumnos = async (grupo: any) => {
    setGrupoViendoAlumnos(grupo);
    setAlumnosGrupo([]);
    setIsAlumnosModalOpen(true);
    setLoading(true);
    try {
      const res = await api.get(`/alumnos?grupoId=${grupo.grupoId || grupo.id}`);
      if (res.data) {
        // Handle both pagination format and array format
        const dataList = res.data.data || res.data;
        setAlumnosGrupo(Array.isArray(dataList) ? dataList : []);
      }
    } catch (error) {
      console.error('Error cargando alumnos', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCrearMateria = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const grupoTarget = grupos.find(g => 
        g.nivel === nuevaMateria.nivel && 
        String(g.grado) === nuevaMateria.grado && 
        g.seccion === nuevaMateria.seccion
      );

      if (!grupoTarget) {
        alert('No se encontró un grupo con ese Nivel, Grado y Sección. Crea el grupo primero.');
        return;
      }

      const horarioStr = nuevaMateria.horariosDia.length > 0 
        ? nuevaMateria.horariosDia.map(h => `${h.dia} ${h.inicio}-${h.fin}`).join(', ')
        : '';
      
      const newMateriaObj = {
        materia: nuevaMateria.nombre,
        tipo: nuevaMateria.tipo,
        docente: nuevaMateria.docente ? parseInt(nuevaMateria.docente) : null,
        horario: horarioStr || null,
        aula: nuevaMateria.aula || null
      };

      if (materiaEditandoInfo) {
        // Editing an existing materia
        let grupoAnterior = grupos.find(g => g.id === materiaEditandoInfo.grupoId || g.grupoId === materiaEditandoInfo.grupoId);
        if (grupoAnterior && (grupoAnterior.grupoId || grupoAnterior.id) !== (grupoTarget.grupoId || grupoTarget.id)) {
          // Changed group: remove from old group, add to new
          const oldMaterias = [...(grupoAnterior.materias || [])];
          oldMaterias.splice(materiaEditandoInfo.index, 1);
          await api.put(`/grupos/${grupoAnterior.id || grupoAnterior.grupoId}`, { materias: oldMaterias });
          
          const targetMaterias = [...(grupoTarget.materias || [])];
          targetMaterias.push(newMateriaObj);
          await api.put(`/grupos/${grupoTarget.id || grupoTarget.grupoId}`, { materias: targetMaterias });
        } else {
          // Same group, just update index
          const updatedMaterias = [...(grupoTarget.materias || [])];
          updatedMaterias[materiaEditandoInfo.index] = newMateriaObj;
          await api.put(`/grupos/${grupoTarget.id || grupoTarget.grupoId}`, { materias: updatedMaterias });
        }
      } else {
        // Creating new materia
        const updatedMaterias = [...(grupoTarget.materias || []), newMateriaObj];
        await api.put(`/grupos/${grupoTarget.id || grupoTarget.grupoId}`, { materias: updatedMaterias });
      }

      setIsMateriaModalOpen(false);
      setMateriaEditandoInfo(null);
      setNuevaMateria({
        nombre: '', tipo: 'curricular', nivel: '', grado: '', seccion: '',
        docente: '', horariosDia: [], aula: ''
      });
      cargarGrupos();
    } catch (error) {
      console.error('Error guardando materia', error);
      alert('Hubo un error al guardar la materia.');
    }
  };

  const handleEditarMateria = (m: any, g: any, index: number) => {
    setMateriaEditandoInfo({ index, grupoId: g.id || g.grupoId });
    // Parse horario: "Lun 10:00-11:00, Mar 12:00-13:00"
    let horariosDiaParsed: {dia: string, inicio: string, fin: string}[] = [];
    if (m.horario) {
      const parts = m.horario.split(',').map((p:string)=>p.trim());
      parts.forEach((p:string) => {
        const match = p.match(/^([A-Za-z]{3})\s+(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})$/);
        if (match) {
          horariosDiaParsed.push({ dia: match[1], inicio: match[2], fin: match[3] });
        } else {
          // Fallback legacy (Lun, Mar 10:00 - 11:00)
          const legacyMatch = m.horario.match(/(.*?)\s+(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})/);
          if (legacyMatch && horariosDiaParsed.length === 0) {
            const lDias = legacyMatch[1].split(',').map((d:string)=>d.trim());
            lDias.forEach((ld:string) => {
              if (['Lun','Mar','Mie','Jue','Vie','Sab'].includes(ld)) {
                horariosDiaParsed.push({ dia: ld, inicio: legacyMatch[2], fin: legacyMatch[3] });
              }
            });
          }
        }
      });
    }

    setNuevaMateria({
      nombre: m.materia || m.nombre,
      tipo: m.tipo || 'curricular',
      nivel: g.nivel,
      grado: String(g.grado),
      seccion: g.seccion,
      docente: m.docente ? docentes.find(d => d.nombre === m.docente || d.nombreCompleto === m.docente)?.id?.toString() || '' : '',
      horariosDia: horariosDiaParsed,
      aula: m.aula || ''
    });
    setIsMateriaModalOpen(true);
  };

  const handleEliminarMateria = async (m: any, g: any, index: number) => {
    if (!window.confirm(`¿Estás seguro de que deseas eliminar la materia ${m.materia || m.nombre}?`)) return;
    try {
      const updatedMaterias = [...(g.materias || [])];
      updatedMaterias.splice(index, 1);
      await api.put(`/grupos/${g.id || g.grupoId}`, { materias: updatedMaterias });
      cargarGrupos();
    } catch (error) {
      console.error('Error eliminando materia', error);
      alert('Hubo un error al eliminar la materia.');
    }
  };

  const handleAbrirAsignarAlumnos = async (m: any, g: any) => {
    setMateriaActualAsignacion({ ...m, grupo: g });
    setAlumnosAsignacionDisponibles([]);
    setAlumnosAsignacionSeleccionados([]);
    setBusquedaAsignacion('');
    setIsAsignarAlumnosModalOpen(true);
    setLoading(true);
    try {
      // Get all active students for this level and grade
      const resAlumnos = await api.get(`/alumnos?estado=Activo&nivel=${g.nivel}&grado=${g.grado}`);
      if (resAlumnos.data) {
        const arr = Array.isArray(resAlumnos.data) ? resAlumnos.data : (resAlumnos.data?.data || []);
        setAlumnosAsignacionDisponibles(arr);
      }
      // Get enrolled students for this materia
      if (m.id) {
        const resAsignados = await api.get(`/grupos/materias/${m.id}/alumnos`);
        if (resAsignados.data) {
          setAlumnosAsignacionSeleccionados(resAsignados.data.map((a: any) => Number(a.id || a.alumnoId)));
        }
      }
    } catch (error) {
      console.error('Error cargando datos para asignar alumnos', error);
    } finally {
      setLoading(false);
    }
  };

  const handleToggleSeleccionAlumnoAsignacion = (id: number) => {
    if (alumnosAsignacionSeleccionados.includes(id)) {
      setAlumnosAsignacionSeleccionados(alumnosAsignacionSeleccionados.filter(i => i !== id));
    } else {
      setAlumnosAsignacionSeleccionados([...alumnosAsignacionSeleccionados, id]);
    }
  };

  const handleGuardarAsignacionAlumnos = async () => {
    try {
      if (!materiaActualAsignacion?.id) {
        alert("La materia no tiene un ID válido. Guárdala primero.");
        return;
      }
      await api.put(`/grupos/materias/${materiaActualAsignacion.id}/alumnos`, {
        alumnosIds: alumnosAsignacionSeleccionados
      });
      setIsAsignarAlumnosModalOpen(false);
      cargarGrupos();
    } catch (error) {
      console.error('Error asignando alumnos', error);
      alert('Hubo un error al asignar los alumnos.');
    }
  };

  const alumnosAsignacionFiltrados = alumnosAsignacionDisponibles.filter(a => {
    const q = busquedaAsignacion.toLowerCase();
    return !q || 
      (a.nombreCompleto || a.nombre || '').toLowerCase().includes(q) || 
      (a.matricula || '').toLowerCase().includes(q);
  });

  // Filter groups in memory since API might not handle all filters or it's faster for small lists
  const gruposFiltrados = grupos.filter(g => {
    if (filtroNivel && g.nivel !== filtroNivel) return false;
    if (filtroGrado && String(g.grado) !== filtroGrado) return false;
    if (filtroSeccion && g.seccion !== filtroSeccion) return false;
    return true;
  });

  return (
    <div className="h-full flex flex-col">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-navy-800">Grupos y materias</h2>
          <p className="text-sm text-gray-500 mt-1">Gestiona los grupos, asigna docentes titulares y administra las materias.</p>
        </div>
        {isAdmin && (
          <button 
            onClick={() => {
              setGrupoEditandoId(null);
              setNuevoGrupo({ nombre: '', nivel: '', grado: '', seccion: '', titular: '', materias: [] });
              setBusquedaDocente('');
              setGrupoPlantillaId('');
              setIsModalOpen(true);
            }}
            className="flex items-center gap-2 px-4 py-2 bg-navy-600 text-white rounded-xl hover:bg-navy-700 transition-colors shadow-sm"
          >
            <Plus size={16} /> Nuevo Grupo
          </button>
        )}
      </div>

      <div className="grid md:grid-cols-3 gap-4 mb-6">
        <div>
          <label className="text-xs font-medium text-gray-600 mb-1 block">Nivel Escolar</label>
          <select 
            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none bg-white"
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
        </div>
        <div>
          <label className="text-xs font-medium text-gray-600 mb-1 block">Grado</label>
          <select 
            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none bg-white"
            value={filtroGrado}
            onChange={(e) => {
              setFiltroGrado(e.target.value);
              setFiltroSeccion('');
            }}
          >
            <option value="">Todos los grados</option>
            {getGrados().map(g => <option key={g} value={g}>{g}° Grado</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs font-medium text-gray-600 mb-1 block">Grupo</label>
          <select 
            className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none bg-white"
            value={filtroSeccion}
            onChange={(e) => setFiltroSeccion(e.target.value)}
          >
            <option value="">Todas las secciones</option>
            {getSecciones().map(s => <option key={s} value={s}>Sección {s}</option>)}
          </select>
        </div>
      </div>

      <div className="flex border-b border-gray-200 mb-6">
        <button 
          className={`px-6 py-3 font-medium text-sm transition-colors border-b-2 flex items-center gap-2 ${
            activeTab === 'grupos' ? 'border-navy-600 text-navy-800' : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
          onClick={() => setActiveTab('grupos')}
        >
          <Users size={16} /> Grupos y Docentes
        </button>
        <button 
          className={`px-6 py-3 font-medium text-sm transition-colors border-b-2 flex items-center gap-2 ${
            activeTab === 'materias' ? 'border-navy-600 text-navy-800' : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
          onClick={() => setActiveTab('materias')}
        >
          <BookOpen size={16} /> Materias y Horarios
        </button>
      </div>

      {activeTab === 'grupos' && (
        <div className="space-y-4">
          <div className="flex justify-between items-center mb-2">
            <span className="bg-navy-50 text-navy-700 px-3 py-1.5 rounded-full text-sm font-medium">
              Grupos encontrados: {gruposFiltrados.length}
            </span>
            <button 
              className="flex items-center gap-2 px-4 py-2 bg-navy-600 text-white rounded-xl hover:bg-navy-700 transition-colors shadow-sm font-medium"
              onClick={() => {
                setGrupoEditandoId(null);
                setNuevoGrupo({ nombre: '', nivel: '', grado: '', seccion: '', titular: '', materias: [] });
                setBusquedaDocente('');
                setGrupoPlantillaId('');
                setIsModalOpen(true);
              }}
            >
              <Plus size={16} /> Nuevo Grupo
            </button>
          </div>

          {loading ? (
            <div className="text-center text-gray-400 py-10">Cargando grupos...</div>
          ) : gruposFiltrados.length === 0 ? (
            <div className="text-center text-gray-400 py-10">No hay grupos que coincidan con los filtros.</div>
          ) : (
            gruposFiltrados.map((grupo) => (
              <div key={grupo.grupoId} className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4 flex justify-between items-center hover:border-gray-200 transition-colors">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-xl bg-blue-50 flex items-center justify-center flex-shrink-0">
                    <span className="font-bold text-blue-700">{grupo.grado}° {grupo.seccion}</span>
                  </div>
                  <div>
                    <div className="font-bold text-navy-700 text-lg">{grupo.nombre}</div>
                    <div className="text-sm text-gray-500 flex gap-4 mt-1 items-center">
                      <span className="bg-navy-50 text-navy-700 px-2 py-0.5 rounded text-xs font-semibold">{grupo.nivel}</span>
                      <span className="flex items-center gap-1"><Users size={12} /> {grupo._count?.alumnos || 0} alumnos</span>
                      <span className="flex items-center gap-1"><BookOpen size={12} /> {grupo.materias?.length || 0} materias</span>
                    </div>
                  </div>
                </div>
                
                <div className="flex gap-4">
                  <div className="text-right">
                    <div className="text-xs text-gray-500 mb-1">Docente Titular</div>
                    <div className="font-medium text-navy-700 bg-gray-50 px-3 py-1 rounded-lg">
                      {grupo.docenteTitular?.nombreCompleto || 'Sin asignar'}
                    </div>
                  </div>
                  {isAdmin && (
                    <div className="flex items-center gap-1 border-l border-gray-100 pl-4 ml-2">
                      <button 
                        className="p-2 text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors" 
                        title="Ver Alumnos"
                        onClick={() => handleVerAlumnos(grupo)}
                      >
                        <Users size={18} />
                      </button>
                      <button 
                        className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors" 
                        title="Editar Grupo"
                        onClick={() => handleEditarGrupo(grupo)}
                      >
                        <Edit size={18} />
                      </button>
                      <button 
                        className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors" 
                        title="Eliminar Grupo"
                        onClick={() => handleEliminarGrupo(grupo.grupoId || grupo.id)}
                      >
                        <Trash2 size={18} />
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {activeTab === 'materias' && (
        <div className="space-y-4">
          <div className="flex justify-between items-center mb-2">
            <span className="bg-navy-50 text-navy-700 px-3 py-1.5 rounded-full text-sm font-medium">
              Materias encontradas: {gruposFiltrados.flatMap(g => g.materias || []).length}
            </span>
            {isAdmin && (
              <button 
                className="flex items-center gap-2 px-4 py-2 bg-navy-600 text-white rounded-xl hover:bg-navy-700 transition-colors shadow-sm font-medium"
                onClick={() => {
                  setMateriaEditandoInfo(null);
                  setNuevaMateria({ nombre: '', tipo: 'curricular', nivel: '', grado: '', seccion: '', docente: '', horariosDia: [], aula: '' });
                  setIsMateriaModalOpen(true);
                }}
              >
                <Plus size={16} /> Nueva Materia
              </button>
            )}
          </div>
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="w-full text-sm text-left">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="p-4 font-semibold text-gray-600">Materia</th>
                  <th className="p-4 font-semibold text-gray-600">Grupo</th>
                  <th className="p-4 font-semibold text-gray-600">Docente</th>
                  <th className="p-4 font-semibold text-gray-600">Horario</th>
                  <th className="p-4 font-semibold text-gray-600">Aula</th>
                  <th className="p-4 font-semibold text-gray-600 text-center">Tipo</th>
                  {isAdmin && <th className="p-4 font-semibold text-gray-600 text-center">Acciones</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {gruposFiltrados.flatMap(g => 
                  (g.materias || []).map((m: any, index: number) => (
                    <tr key={m.id || `${g.id}-${index}`} className="hover:bg-gray-50 transition-colors">
                      <td className="p-4 font-bold text-navy-700">{m.materia || 'Sin nombre'}</td>
                      <td className="p-4">
                        <span className="bg-navy-50 text-navy-700 px-2 py-0.5 rounded text-xs font-semibold">
                          {g.grado}° {g.seccion} {g.nivel}
                        </span>
                      </td>
                      <td className="p-4 text-gray-700">{m.docente || 'Sin Asignar'}</td>
                      <td className="p-4 text-gray-500">{m.horario || '-'}</td>
                      <td className="p-4 text-gray-500">{m.aula || '-'}</td>
                      <td className="p-4 text-center">
                        <span className={`px-2 py-1 rounded text-xs font-medium ${
                          m.tipo === 'curricular' ? 'bg-blue-50 text-blue-700' :
                          m.tipo === 'taller' ? 'bg-orange-50 text-orange-700' :
                          'bg-purple-50 text-purple-700'
                        }`}>
                          {m.tipo === 'curricular' ? 'Curricular' : m.tipo === 'taller' ? 'Taller' : 'Extra'}
                        </span>
                      </td>
                      {isAdmin && (
                        <td className="p-4 text-center flex justify-center gap-1">
                          <button 
                            className="p-2 text-indigo-600 hover:bg-indigo-50 rounded transition-colors" 
                            title="Inscribir Alumnos" 
                            onClick={() => handleAbrirAsignarAlumnos(m, g)}
                          >
                            <Users size={16} />
                          </button>
                          <button 
                            className="p-2 text-blue-600 hover:bg-blue-50 rounded transition-colors" 
                            title="Editar Materia" 
                            onClick={() => handleEditarMateria(m, g, index)}
                          >
                            <Edit size={16} />
                          </button>
                          <button 
                            className="p-2 text-red-600 hover:bg-red-50 rounded transition-colors" 
                            title="Eliminar Materia" 
                            onClick={() => handleEliminarMateria(m, g, index)}
                          >
                            <Trash2 size={16} />
                          </button>
                        </td>
                      )}
                    </tr>
                  ))
                )}
                {gruposFiltrados.flatMap(g => g.materias || []).length === 0 && (
                  <tr>
                    <td colSpan={isAdmin ? 7 : 6} className="p-8 text-center text-gray-400">
                      No hay materias asignadas en los grupos filtrados.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Modal Ver Alumnos */}
      {isAlumnosModalOpen && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl w-full max-w-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h3 className="text-lg font-bold text-navy-800">
                Alumnos en {grupoViendoAlumnos?.nombre}
              </h3>
              <button onClick={() => setIsAlumnosModalOpen(false)} className="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-gray-100 transition-colors">
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 overflow-y-auto">
              {loading ? (
                <div className="text-center py-10 text-gray-500">Cargando alumnos...</div>
              ) : alumnosGrupo.length === 0 ? (
                <div className="text-center py-10 text-gray-500 bg-gray-50 rounded-2xl">
                  No hay alumnos inscritos en este grupo.
                  <br/>
                  <span className="text-sm">Ve al módulo de Alumnos para inscribirlos o editarlos.</span>
                </div>
              ) : (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                  <table className="w-full text-sm text-left">
                    <thead className="bg-gray-50 border-b border-gray-200">
                      <tr>
                        <th className="p-4 font-semibold text-gray-600">Matrícula</th>
                        <th className="p-4 font-semibold text-gray-600">Nombre</th>
                        <th className="p-4 font-semibold text-gray-600">Estado</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                      {alumnosGrupo.map((a: any) => (
                        <tr key={a.alumnoId || a.id} className="hover:bg-gray-50">
                          <td className="p-4 font-medium text-gray-500">{a.matricula || '-'}</td>
                          <td className="p-4 font-bold text-navy-700">{a.nombreCompleto || a.nombre}</td>
                          <td className="p-4">
                            <span className="bg-green-50 text-green-700 px-2 py-1 rounded text-xs font-semibold">
                              Inscrito
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Modal Nuevo/Editar Grupo */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h3 className="text-lg font-bold text-navy-800">{grupoEditandoId ? 'Editar Grupo' : 'Crear Nuevo Grupo'}</h3>
              <button onClick={() => setIsModalOpen(false)} className="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-gray-100 transition-colors">
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleCrearGrupo} className="p-6 space-y-6">
              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Nivel Educativo *</label>
                  <select 
                    required
                    disabled={!!grupoEditandoId}
                    className={`w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none ${grupoEditandoId ? 'bg-gray-100 cursor-not-allowed' : ''}`}
                    value={nuevoGrupo.nivel}
                    onChange={(e) => setNuevoGrupo({...nuevoGrupo, nivel: e.target.value, grado: '', seccion: ''})}
                  >
                    <option value="">- Nivel -</option>
                    {nivelesDisponibles.map(n => <option key={n} value={n}>{n}</option>)}
                  </select>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Grado *</label>
                  <select 
                    required
                    disabled={!!grupoEditandoId}
                    className={`w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none ${grupoEditandoId ? 'bg-gray-100 cursor-not-allowed' : ''}`}
                    value={nuevoGrupo.grado}
                    onChange={(e) => setNuevoGrupo({...nuevoGrupo, grado: e.target.value})}
                  >
                    <option value="">- Grado -</option>
                    {nuevoGrupo.nivel ? (nuevoGrupo.nivel === 'PREESCOLAR' ? ['1','2','3'] : ['1','2','3','4','5','6']).map(g => (
                      <option key={g} value={g}>{g}°</option>
                    )) : null}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Sección (Grupo) *</label>
                  <input 
                    required
                    disabled={!!grupoEditandoId}
                    type="text"
                    placeholder="EJ. A, B"
                    className={`w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none uppercase ${grupoEditandoId ? 'bg-gray-100 cursor-not-allowed' : ''}`}
                    value={nuevoGrupo.seccion}
                    onChange={(e) => setNuevoGrupo({...nuevoGrupo, seccion: e.target.value.toUpperCase()})}
                  />
                </div>
              </div>

              {!grupoEditandoId && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Clonar materias de un grupo existente (Plantilla)</label>
                  <div className="flex gap-2">
                    <select 
                      className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                      value={grupoPlantillaId}
                      onChange={(e) => setGrupoPlantillaId(e.target.value)}
                    >
                      <option value="">Selecciona un grupo plantilla...</option>
                      {grupos.map(g => (
                        <option key={g.id || g.grupoId} value={g.id || g.grupoId}>
                          {g.nombre || `${g.grado}°${g.seccion} ${g.nivel}`}
                        </option>
                      ))}
                    </select>
                    <button 
                      type="button"
                      onClick={handleCargarMateriasPlantilla}
                      className="px-4 py-2.5 rounded-xl border border-gray-200 text-gray-700 hover:bg-gray-50 transition-colors font-medium bg-white"
                    >
                      Cargar materias
                    </button>
                  </div>
                </div>
              )}

              <div className="relative">
                <label className="block text-sm font-medium text-gray-700 mb-1">Docente Titular (Opcional)</label>
                <div className="relative">
                  <Search size={18} className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
                  <input 
                    type="text" 
                    placeholder="Buscar maestro titular..."
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                    value={busquedaDocente}
                    onChange={(e) => {
                      setBusquedaDocente(e.target.value);
                      setMostrarDropdownDocente(true);
                      if (e.target.value === '') setNuevoGrupo({...nuevoGrupo, titular: ''});
                    }}
                    onFocus={() => setMostrarDropdownDocente(true)}
                  />
                </div>
                <p className="text-xs text-gray-500 mt-1">Busca y selecciona un usuario con rol Docente.</p>
                
                {mostrarDropdownDocente && busquedaDocente && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-xl shadow-lg max-h-48 overflow-y-auto">
                    {docentes
                      .filter(d => (d.nombre || d.nombreCompleto || '').toLowerCase().includes(busquedaDocente.toLowerCase()))
                      .map(d => (
                        <div 
                          key={d.id} 
                          className="px-4 py-2 hover:bg-gray-50 cursor-pointer text-sm"
                          onClick={() => {
                            setNuevoGrupo({...nuevoGrupo, titular: d.id.toString()});
                            setBusquedaDocente(d.nombre || d.nombreCompleto);
                            setMostrarDropdownDocente(false);
                          }}
                        >
                          {d.nombre || d.nombreCompleto}
                        </div>
                      ))}
                  </div>
                )}
              </div>

              <div className="pt-2 flex justify-end gap-3">
                <button 
                  type="button" 
                  onClick={() => setIsModalOpen(false)}
                  className="px-6 py-2.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 hover:bg-gray-50 rounded-xl transition-colors"
                >
                  Cancelar
                </button>
                <button 
                  type="submit"
                  className="px-6 py-2.5 text-sm font-medium text-white bg-navy-800 hover:bg-navy-900 rounded-xl transition-colors shadow-sm"
                >
                  {grupoEditandoId ? 'Actualizar Grupo' : 'Guardar Grupo'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Inscribir Alumnos a Materia */}
      {isAsignarAlumnosModalOpen && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl w-full max-w-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <div>
                <h3 className="text-lg font-bold text-navy-800 flex items-center gap-2">
                  Inscribir Alumnos
                  <span className="bg-gray-200 text-gray-700 text-xs px-2 py-1 rounded-full font-medium">
                    {alumnosAsignacionDisponibles.length} alumnos
                  </span>
                </h3>
                <p className="text-sm text-gray-500 mt-1">
                  Materia: {materiaActualAsignacion?.materia || materiaActualAsignacion?.nombre}
                </p>
              </div>
              <button onClick={() => setIsAsignarAlumnosModalOpen(false)} className="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-gray-100 transition-colors">
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 flex-1 overflow-hidden flex flex-col">
              <div className="mb-4 relative">
                <Search size={18} className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
                <input 
                  type="text" 
                  placeholder="Buscar alumno por nombre o matrícula..."
                  className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none text-sm"
                  value={busquedaAsignacion}
                  onChange={(e) => setBusquedaAsignacion(e.target.value)}
                />
              </div>

              <div className="flex-1 overflow-y-auto border border-gray-200 rounded-xl">
                <table className="w-full text-sm text-left">
                  <thead className="bg-gray-50 sticky top-0 z-10 shadow-sm">
                    <tr>
                      <th className="p-3 w-16 text-center font-semibold text-gray-600">Inscrito</th>
                      <th className="p-3 font-semibold text-gray-600">Matrícula</th>
                      <th className="p-3 font-semibold text-gray-600">Nombre del Alumno</th>
                      <th className="p-3 font-semibold text-gray-600">Grado</th>
                      <th className="p-3 font-semibold text-gray-600">Grupo</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {alumnosAsignacionFiltrados.map((a: any) => {
                      const id = Number(a.alumnoId || a.id);
                      const isSelected = alumnosAsignacionSeleccionados.includes(id);
                      return (
                        <tr key={id} className={`hover:bg-blue-50/50 transition-colors cursor-pointer ${isSelected ? 'bg-blue-50/30' : ''}`} onClick={() => handleToggleSeleccionAlumnoAsignacion(id)}>
                          <td className="p-3 text-center">
                            <input 
                              type="checkbox"
                              checked={isSelected}
                              onChange={() => handleToggleSeleccionAlumnoAsignacion(id)}
                              className="w-4 h-4 text-navy-600 border-gray-300 rounded focus:ring-navy-500 cursor-pointer"
                              onClick={(e) => e.stopPropagation()}
                            />
                          </td>
                          <td className="p-3 text-gray-500">{a.matricula || '-'}</td>
                          <td className="p-3 font-medium text-navy-800">{a.nombreCompleto || a.nombre}</td>
                          <td className="p-3 text-gray-600">{a.grado || materiaActualAsignacion?.grupo?.grado}°</td>
                          <td className="p-3 text-gray-600">{a.seccion || materiaActualAsignacion?.grupo?.seccion}</td>
                        </tr>
                      );
                    })}
                    {alumnosAsignacionFiltrados.length === 0 && (
                      <tr>
                        <td colSpan={5} className="p-8 text-center text-gray-400">
                          No se encontraron alumnos para asignar en este nivel y grado.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            <div className="p-4 border-t border-gray-100 flex justify-end gap-3 bg-gray-50/50">
              <button 
                onClick={() => setIsAsignarAlumnosModalOpen(false)}
                className="px-6 py-2.5 rounded-xl border border-gray-200 text-gray-600 hover:bg-gray-100 transition-colors font-medium bg-white shadow-sm"
              >
                Cancelar
              </button>
              <button 
                onClick={handleGuardarAsignacionAlumnos}
                className="px-6 py-2.5 rounded-xl bg-navy-800 text-white hover:bg-navy-900 transition-colors font-medium shadow-md flex items-center gap-2"
                disabled={loading}
              >
                {loading ? 'Guardando...' : 'Guardar Inscripciones'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal Nueva Materia */}
      {isMateriaModalOpen && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl w-full max-w-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h3 className="text-lg font-bold text-navy-800">{materiaEditandoInfo ? 'Editar Materia' : 'Nueva Materia'}</h3>
              <button onClick={() => setIsMateriaModalOpen(false)} className="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-gray-100 transition-colors">
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleCrearMateria} className="p-6 space-y-6 overflow-y-auto">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nombre de la Materia *</label>
                <input 
                  type="text" 
                  required
                  placeholder="Ej. Matemáticas"
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={nuevaMateria.nombre}
                  onChange={(e) => setNuevaMateria({...nuevaMateria, nombre: e.target.value})}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Tipo de Materia *</label>
                <div className="flex gap-3">
                  {['curricular', 'extracurricular', 'taller'].map(tipo => (
                    <button
                      key={tipo}
                      type="button"
                      onClick={() => setNuevaMateria({...nuevaMateria, tipo})}
                      className={`px-4 py-2 rounded-xl text-sm font-medium transition-colors ${
                        nuevaMateria.tipo === tipo 
                          ? 'bg-navy-800 text-white shadow-md' 
                          : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
                      }`}
                    >
                      {tipo.charAt(0).toUpperCase() + tipo.slice(1)}
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Nivel *</label>
                  <select 
                    required
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                    value={nuevaMateria.nivel}
                    onChange={(e) => setNuevaMateria({...nuevaMateria, nivel: e.target.value, grado: '', seccion: ''})}
                  >
                    <option value="">- Nivel -</option>
                    {nivelesDisponibles.map(n => <option key={n} value={n}>{n}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Grado *</label>
                  <select 
                    required
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                    value={nuevaMateria.grado}
                    onChange={(e) => setNuevaMateria({...nuevaMateria, grado: e.target.value, seccion: ''})}
                    disabled={!nuevaMateria.nivel}
                  >
                    <option value="">- Grado -</option>
                    {nuevaMateria.nivel === 'PREESCOLAR' 
                      ? ['1','2','3'].map(g => <option key={g} value={g}>{g}</option>)
                      : ['1','2','3','4','5','6'].map(g => <option key={g} value={g}>{g}</option>)
                    }
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Sección *</label>
                  <select 
                    required
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                    value={nuevaMateria.seccion}
                    onChange={(e) => setNuevaMateria({...nuevaMateria, seccion: e.target.value})}
                    disabled={!nuevaMateria.grado}
                  >
                    <option value="">- Sección -</option>
                    {['A','B','C','D','E','F'].map(s => <option key={s} value={s}>{s}</option>)}
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Docente Asignado *</label>
                <select
                  required
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={nuevaMateria.docente}
                  onChange={(e) => setNuevaMateria({...nuevaMateria, docente: e.target.value})}
                >
                  <option value="">Buscar maestro...</option>
                  {docentes.map(d => (
                    <option key={d.id} value={d.id}>{d.nombre}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Días y Horarios de Impartición</label>
                <div className="flex gap-2 flex-wrap mb-4">
                  {['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'].map(dia => {
                    const idx = nuevaMateria.horariosDia.findIndex(h => h.dia === dia);
                    const isSelected = idx >= 0;
                    return (
                      <button
                        key={dia}
                        type="button"
                        onClick={() => {
                          if (isSelected) {
                            setNuevaMateria({...nuevaMateria, horariosDia: nuevaMateria.horariosDia.filter(h => h.dia !== dia)});
                          } else {
                            setNuevaMateria({...nuevaMateria, horariosDia: [...nuevaMateria.horariosDia, { dia, inicio: '08:00', fin: '09:00' }]});
                          }
                        }}
                        className={`px-4 py-2 rounded-xl text-sm transition-colors border ${
                          isSelected ? 'bg-navy-50 border-navy-300 text-navy-800 font-bold shadow-sm' : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50'
                        }`}
                      >
                        {dia}
                      </button>
                    )
                  })}
                </div>

                {nuevaMateria.horariosDia.length > 0 && (
                  <div className="space-y-3 bg-gray-50 p-4 rounded-xl border border-gray-100">
                    {nuevaMateria.horariosDia.map((horario, index) => (
                      <div key={horario.dia} className="flex items-center gap-4">
                        <div className="w-16 font-bold text-navy-800">{horario.dia}</div>
                        <div className="flex items-center gap-2 flex-1">
                          <input 
                            type="time" 
                            className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none text-sm"
                            value={horario.inicio}
                            onChange={(e) => {
                              const newH = [...nuevaMateria.horariosDia];
                              newH[index].inicio = e.target.value;
                              setNuevaMateria({...nuevaMateria, horariosDia: newH});
                            }}
                          />
                          <span className="text-gray-400">a</span>
                          <input 
                            type="time" 
                            className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none text-sm"
                            value={horario.fin}
                            onChange={(e) => {
                              const newH = [...nuevaMateria.horariosDia];
                              newH[index].fin = e.target.value;
                              setNuevaMateria({...nuevaMateria, horariosDia: newH});
                            }}
                          />
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Aula Asignada</label>
                <input 
                  type="text" 
                  placeholder="Ej. Aula 101, Lab de Computo..."
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={nuevaMateria.aula}
                  onChange={(e) => setNuevaMateria({...nuevaMateria, aula: e.target.value})}
                />
              </div>

              <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
                <button 
                  type="button"
                  onClick={() => setIsMateriaModalOpen(false)}
                  className="px-6 py-2.5 rounded-xl border border-gray-200 text-gray-600 hover:bg-gray-50 transition-colors font-medium"
                >
                  Cancelar
                </button>
                <button 
                  type="submit"
                  className="px-6 py-2.5 rounded-xl bg-navy-800 text-white hover:bg-navy-900 transition-colors font-medium shadow-md"
                >
                  {materiaEditandoInfo ? 'Actualizar Materia' : 'Guardar Materia'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
