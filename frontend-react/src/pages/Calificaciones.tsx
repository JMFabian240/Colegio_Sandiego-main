import React, { useState, useEffect } from 'react';
import { Search, Award, CheckCircle2, ChevronLeft, BookOpen, Star } from 'lucide-react';
import api from '../services/api';
import { useAuthStore } from '../store/useAuthStore';

export function Calificaciones() {
  const { user } = useAuthStore();
  const esMaestra = user?.rol === 'MAESTRA';
  
  const [busqueda, setBusqueda] = useState('');
  const [nivel, setNivel] = useState('');
  const [grado, setGrado] = useState('');
  const [seccion, setSeccion] = useState('');
  
  const [alumnos, setAlumnos] = useState<any[]>([]);
  const [loadingSearch, setLoadingSearch] = useState(false);
  
  const [alumnoSeleccionado, setAlumnoSeleccionado] = useState<any>(null);
  const [tabActual, setTabActual] = useState<'curricular' | 'extracurricular' | 'taller'>('curricular');
  
  const [esPreescolar, setEsPreescolar] = useState(false);
  const [materias, setMaterias] = useState<any[]>([]);
  const [clubes, setClubes] = useState<any[]>([]);
  
  const [saving, setSaving] = useState(false);

  const nivelesDisponibles = ['PREESCOLAR', 'PRIMARIA', 'SECUNDARIA', 'BACHILLERATO'];

  // Debounce search
  useEffect(() => {
    const timer = setTimeout(() => {
      buscarAlumnos();
    }, 400);
    return () => clearTimeout(timer);
  }, [busqueda, nivel, grado, seccion]);

  const buscarAlumnos = async () => {
    if (!busqueda && !nivel && !grado && !seccion) {
      setAlumnos([]);
      return;
    }
    setLoadingSearch(true);
    try {
      const params: any = {};
      if (busqueda) params.q = busqueda;
      if (nivel) params.nivel = nivel;
      if (grado) params.grado = grado;
      if (seccion) params.seccion = seccion;
      
      const res = await api.get('/alumnos', { params });
      // Depending on pagination
      const data = res.data.data || res.data;
      setAlumnos(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error buscando alumnos', error);
      setAlumnos([]);
    } finally {
      setLoadingSearch(false);
    }
  };

  const seleccionarAlumno = async (al: any) => {
    setAlumnoSeleccionado(al);
    setTabActual('curricular');
    setMaterias([]);
    setClubes([]);
    
    // Check if preescolar
    const nivelAl = al.nivel?.codigo || al.nivel;
    const isPre = nivelAl === 'PREESCOLAR';
    setEsPreescolar(isPre);

    try {
      // 1. Cargar grupo para materias curriculares
      if (al.grupoId) {
        const resG = await api.get(`/grupos/${al.grupoId}`);
        if (resG.data && resG.data.materias) {
          const mats = resG.data.materias
            .filter((m: any) => m.tipo === 'curricular' || !m.tipo)
            .map((m: any) => ({
              id: m.id || m.grupoMateriaId,
              nombre: m.materia || m.nombre,
              T1: { v: '', t: '' },
              T2: { v: '', t: '' },
              T3: { v: '', t: '' },
              prom: '-'
            }));
          
          // 2. Cargar calificaciones curriculares
          const resC = await api.get(`/calificaciones/alumno/${al.id}`);
          if (resC.data) {
            resC.data.forEach((c: any) => {
              const mat = mats.find((m: any) => m.id === c.grupoMateriaId);
              if (mat) {
                const k = String(c.periodo).includes('1') ? 'T1' : String(c.periodo).includes('2') ? 'T2' : 'T3';
                mat[k].v = c.valor !== null ? c.valor : '';
                mat[k].t = c.textoObservacion || '';
              }
            });
          }
          setMaterias(recalcularPromedios(mats, isPre));
        }
      }

      // 3. Extracurriculares (Simulado o real si existe el endpoint)
      if (al.materiasExtra) {
        const clubsInit = al.materiasExtra
          .filter((m: any) => m.tipo === 'club')
          .map((m: any) => ({
             id: m.materia,
             nombre: m.materia,
             T1: { v: '', orig: null, califId: null },
             T2: { v: '', orig: null, califId: null },
             T3: { v: '', orig: null, califId: null },
             prom: '-'
          }));
          
        try {
          const resE = await api.get(`/calificaciones/extra/alumno/${al.id}`);
          if (resE.data) {
             resE.data.forEach((c: any) => {
               const club = clubsInit.find((x:any) => x.id === c.club);
               if (club) {
                 const num = c.periodo?.numero || c.numeroTrimestre;
                 const key = num === 1 ? 'T1' : num === 2 ? 'T2' : num === 3 ? 'T3' : null;
                 if (key) {
                   club[key].v = c.valorNumerico;
                   club[key].orig = c.valorNumerico;
                   club[key].califId = c.calificacionExtracurricularId || c.id;
                 }
               }
             });
          }
        } catch (e) { console.warn("No extra grades route or data", e); }
        
        setClubes(recalcularPromedios(clubsInit, false));
      }

    } catch (error) {
      console.error('Error cargando detalles del alumno', error);
    }
  };

  const recalcularPromedios = (lista: any[], isPre: boolean) => {
    return lista.map(item => {
      if (isPre) {
        item.prom = 'N/A';
        return item;
      }
      let s = 0, c = 0;
      ['T1', 'T2', 'T3'].forEach(t => {
        if (item[t].v !== '') {
          let v = parseFloat(item[t].v);
          if (v > 10) { item[t].v = 10; v = 10; }
          if (v < 0) { item[t].v = 0; v = 0; }
          s += v; c++;
        }
      });
      item.prom = c > 0 ? (s / c).toFixed(1) : '-';
      return item;
    });
  };

  const handleMateriaChange = (id: string, trim: string, field: 'v'|'t', value: string) => {
    const updated = materias.map(m => {
      if (m.id === id) {
        m[trim][field] = value;
      }
      return m;
    });
    setMaterias(recalcularPromedios(updated, esPreescolar));
  };

  const guardarCalificaciones = async () => {
    const lote: any[] = [];
    const periodos = ['TRIMESTRE_1', 'TRIMESTRE_2', 'TRIMESTRE_3'];
    
    materias.forEach(mat => {
      ['T1', 'T2', 'T3'].forEach((t, i) => {
        if (esPreescolar) {
          const obs = mat[t].t?.trim();
          if (obs) {
            lote.push({ alumnoId: alumnoSeleccionado.id, grupoMateriaId: mat.id, periodo: periodos[i], valor: null, textoObservacion: obs, tipoEvaluacion: 'observacion' });
          }
        } else {
          const val = parseFloat(mat[t].v);
          if (!isNaN(val) && val >= 0 && val <= 10) {
            lote.push({ alumnoId: alumnoSeleccionado.id, grupoMateriaId: mat.id, periodo: periodos[i], valor: val, tipoEvaluacion: 'numerica' });
          }
        }
      });
    });

    if (lote.length === 0) {
      alert('No hay calificaciones válidas para guardar.');
      return;
    }

    setSaving(true);
    try {
      await api.post('/calificaciones/lote', lote);
      alert('Calificaciones guardadas correctamente.');
    } catch (error) {
      console.error('Error guardando', error);
      alert('Error al guardar calificaciones');
    } finally {
      setSaving(false);
    }
  };

  const getPromedioGeneral = () => {
    if (esPreescolar) return 'N/A';
    const num = materias.filter(m => m.prom !== '-').length;
    const sum = materias.filter(m => m.prom !== '-').reduce((acc, curr) => acc + parseFloat(curr.prom), 0);
    return num > 0 ? (sum / num).toFixed(1) : '-';
  };

  return (
    <div className="h-full flex flex-col relative overflow-hidden">
      {!alumnoSeleccionado ? (
        <>
          <div className="mb-6">
            <h2 className="text-2xl font-bold text-navy-800 flex items-center gap-2">
              <Award className="text-navy-600" /> Evaluación Académica
            </h2>
            <p className="text-sm text-gray-500 mt-1">Busca a un alumno para registrar o consultar sus calificaciones.</p>
          </div>

          <div className="grid md:grid-cols-4 gap-4 mb-6">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
              <input 
                type="text" 
                placeholder="Nombre o matrícula..." 
                className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                value={busqueda}
                onChange={(e) => setBusqueda(e.target.value)}
              />
            </div>
            <select 
              className="px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
              value={nivel}
              onChange={(e) => { setNivel(e.target.value); setGrado(''); setSeccion(''); }}
            >
              <option value="">Todos los niveles</option>
              {nivelesDisponibles.map(n => <option key={n} value={n}>{n}</option>)}
            </select>
            <select 
              className="px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none disabled:bg-gray-50"
              value={grado}
              onChange={(e) => { setGrado(e.target.value); setSeccion(''); }}
              disabled={!nivel}
            >
              <option value="">Todos los grados</option>
              {['1','2','3','4','5','6'].map(g => <option key={g} value={g}>{g}°</option>)}
            </select>
            <select 
              className="px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none disabled:bg-gray-50"
              value={seccion}
              onChange={(e) => setSeccion(e.target.value)}
              disabled={!grado}
            >
              <option value="">Todas las secciones</option>
              {['A','B','C','D','E','F'].map(s => <option key={s} value={s}>{s}</option>)}
            </select>
          </div>

          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 overflow-auto">
            {loadingSearch ? (
              <div className="p-10 text-center text-gray-400">Buscando...</div>
            ) : alumnos.length === 0 ? (
              <div className="p-10 text-center text-gray-400 flex flex-col items-center">
                <Search className="w-12 h-12 mb-3 text-gray-200" />
                <p>No se encontraron alumnos con los criterios de búsqueda.</p>
              </div>
            ) : (
              <table className="w-full text-sm text-left">
                <thead className="bg-gray-50 border-b border-gray-200 sticky top-0">
                  <tr>
                    <th className="p-4 font-semibold text-gray-600">Alumno</th>
                    <th className="p-4 font-semibold text-gray-600">Matrícula</th>
                    <th className="p-4 font-semibold text-gray-600">Nivel / Grado</th>
                    <th className="p-4 font-semibold text-gray-600 text-right">Acción</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {alumnos.map(al => (
                    <tr key={al.id} className="hover:bg-gray-50 transition-colors">
                      <td className="p-4">
                        <div className="font-bold text-navy-800">{al.nombre}</div>
                      </td>
                      <td className="p-4 font-mono text-gray-500">{al.matricula}</td>
                      <td className="p-4">
                        <span className="bg-navy-50 text-navy-700 px-2.5 py-1 rounded-md text-xs font-semibold">
                          {al.grado}° {al.seccion} {al.nivel?.codigo || al.nivel}
                        </span>
                      </td>
                      <td className="p-4 text-right">
                        <button 
                          onClick={() => seleccionarAlumno(al)}
                          className="px-4 py-1.5 text-xs font-medium text-white bg-navy-600 rounded-lg hover:bg-navy-700 transition-colors shadow-sm"
                        >
                          Evaluar
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      ) : (
        <div className="flex flex-col h-full">
          <div className="mb-6 flex justify-between items-start">
            <div>
              <button 
                onClick={() => setAlumnoSeleccionado(null)}
                className="flex items-center gap-1 text-sm text-gray-500 hover:text-navy-600 transition-colors mb-2"
              >
                <ChevronLeft size={16} /> Volver a la búsqueda
              </button>
              <h2 className="text-2xl font-bold text-navy-800">{alumnoSeleccionado.nombre}</h2>
              <div className="flex items-center gap-3 mt-1">
                <span className="bg-navy-50 text-navy-700 px-2.5 py-0.5 rounded text-xs font-semibold">
                  {alumnoSeleccionado.matricula}
                </span>
                <span className="text-sm text-gray-500 font-medium">
                  {alumnoSeleccionado.grado}° {alumnoSeleccionado.seccion} {alumnoSeleccionado.nivel?.codigo || alumnoSeleccionado.nivel}
                </span>
              </div>
            </div>
            
            {!esPreescolar && (
              <div className="bg-white px-5 py-3 rounded-2xl border border-gray-100 shadow-sm text-center">
                <div className="text-[10px] uppercase font-bold text-gray-400 tracking-wider mb-0.5">Promedio Gral.</div>
                <div className="text-3xl font-black text-navy-800">{getPromedioGeneral()}</div>
              </div>
            )}
          </div>

          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 flex flex-col overflow-hidden">
            <div className="flex border-b border-gray-100 px-2 pt-2 bg-gray-50/50">
              <button 
                className={`px-6 py-3 font-medium text-sm transition-colors border-b-2 flex items-center gap-2 ${tabActual === 'curricular' ? 'border-navy-600 text-navy-800 bg-white rounded-t-xl' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
                onClick={() => setTabActual('curricular')}
              >
                <BookOpen size={16} /> Curriculares
              </button>
              <button 
                className={`px-6 py-3 font-medium text-sm transition-colors border-b-2 flex items-center gap-2 ${tabActual === 'extracurricular' ? 'border-navy-600 text-navy-800 bg-white rounded-t-xl' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
                onClick={() => setTabActual('extracurricular')}
              >
                <Star size={16} /> Extracurriculares
              </button>
            </div>

            <div className="p-6 flex-1 overflow-auto">
              {tabActual === 'curricular' && (
                <div>
                  <table className="w-full text-sm text-left mb-6">
                    <thead className="bg-gray-50 text-gray-600 rounded-lg">
                      <tr>
                        <th className="p-3 font-semibold rounded-tl-lg">Materia</th>
                        <th className="p-3 font-semibold text-center w-40">Trimestre 1</th>
                        <th className="p-3 font-semibold text-center w-40">Trimestre 2</th>
                        <th className="p-3 font-semibold text-center w-40">Trimestre 3</th>
                        <th className="p-3 font-semibold text-center w-24 rounded-tr-lg">Promedio</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                      {materias.length === 0 && (
                        <tr><td colSpan={5} className="p-6 text-center text-gray-400">Este alumno no tiene materias curriculares asignadas.</td></tr>
                      )}
                      {materias.map(mat => (
                        <tr key={mat.id} className="hover:bg-gray-50/50 transition-colors group">
                          <td className="p-3 font-medium text-gray-800">{mat.nombre}</td>
                          {['T1', 'T2', 'T3'].map((trim: any) => (
                            <td key={trim} className="p-2">
                              {esPreescolar ? (
                                <textarea 
                                  className="w-full bg-white border border-gray-200 rounded-lg p-2 text-xs h-12 resize-none focus:ring-2 focus:ring-navy-500 outline-none transition-shadow"
                                  placeholder="Observaciones..."
                                  value={mat[trim].t}
                                  onChange={(e) => handleMateriaChange(mat.id, trim, 't', e.target.value)}
                                />
                              ) : (
                                <input 
                                  type="number" 
                                  min="0" max="10" step="0.1"
                                  className="w-full bg-white border border-gray-200 rounded-lg p-2 text-center focus:ring-2 focus:ring-navy-500 outline-none transition-shadow font-medium"
                                  value={mat[trim].v}
                                  onChange={(e) => handleMateriaChange(mat.id, trim, 'v', e.target.value)}
                                />
                              )}
                            </td>
                          ))}
                          <td className="p-3 text-center">
                            <span className={`font-bold px-3 py-1 rounded-full text-xs ${
                              mat.prom === 'N/A' || mat.prom === '-' ? 'text-gray-400 bg-gray-100' :
                              parseFloat(mat.prom) < 6 ? 'text-red-700 bg-red-50' : 'text-emerald-700 bg-emerald-50'
                            }`}>
                              {mat.prom}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>

                  <div className="flex justify-end gap-3 mt-4 pt-4 border-t border-gray-100">
                    <button className="px-6 py-2.5 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors" onClick={() => setAlumnoSeleccionado(null)}>Cancelar</button>
                    <button 
                      onClick={guardarCalificaciones} 
                      disabled={saving || materias.length === 0}
                      className="flex items-center gap-2 px-6 py-2.5 bg-navy-600 text-white rounded-xl hover:bg-navy-700 transition-colors shadow-sm font-medium disabled:opacity-70"
                    >
                      <CheckCircle2 size={18} /> {saving ? 'Guardando...' : 'Guardar Calificaciones'}
                    </button>
                  </div>
                </div>
              )}

              {tabActual === 'extracurricular' && (
                <div className="text-center py-12 text-gray-400">
                  <Star className="w-12 h-12 mx-auto mb-4 text-gray-200" />
                  <p>Módulo de clubes extracurriculares en desarrollo.</p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
