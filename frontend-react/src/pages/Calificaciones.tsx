import React, { useState, useEffect } from 'react';
import { Award, CheckCircle2, Search, BookOpen, Star, AlertCircle, Save } from 'lucide-react';
import { gruposService } from '../services/grupos.service';
import { alumnosService } from '../services/alumnos.service';
import { calificacionesService } from '../services/calificaciones.service';
import { useAuthStore } from '../store/useAuthStore';

export function Calificaciones() {
  const { user } = useAuthStore();
  const esMaestra = user?.rol === 'MAESTRA';

  // --- Data States ---
  const [grupos, setGrupos] = useState<any[]>([]);
  const [grupoSeleccionadoId, setGrupoSeleccionadoId] = useState<string>('');
  const [grupoSeleccionado, setGrupoSeleccionado] = useState<any>(null);

  const [materias, setMaterias] = useState<any[]>([]);
  const [materiaSeleccionadaId, setMateriaSeleccionadaId] = useState<string>('');
  
  const [alumnos, setAlumnos] = useState<any[]>([]);
  
  // State for the grades grid: { [alumnoId]: { T1: {v, t}, T2: {v, t}, T3: {v, t} } }
  const [grid, setGrid] = useState<Record<number, any>>({});

  // --- UI States ---
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [esPreescolar, setEsPreescolar] = useState(false);

  // 1. Fetch all groups on mount
  useEffect(() => {
    const fetchGrupos = async () => {
      try {
        const res: any = await gruposService.obtenerTodos({ limit: 1000 });
      setGrupos(res.data?.data || res.data || []);
      } catch (err) {
        console.error('Error fetching grupos:', err);
      }
    };
    fetchGrupos();
  }, []);

  // 2. When a group is selected, fetch its details (for subjects)
  useEffect(() => {
    if (!grupoSeleccionadoId) {
      setGrupoSeleccionado(null);
      setMaterias([]);
      setMateriaSeleccionadaId('');
      setAlumnos([]);
      setGrid({});
      return;
    }

    const fetchGrupoDetails = async () => {
      setLoading(true);
      try {
        const resG: any = await gruposService.obtenerPorId(Number(grupoSeleccionadoId));
        const grupo = resG.data || resG;
        setGrupoSeleccionado(grupo);
        
        // Determine if Preescolar based on "nivel" field or "Nivel" string
        const nivelStr = typeof grupo.nivel === 'string' ? grupo.nivel : (grupo.nivel?.codigo || '');
        setEsPreescolar(nivelStr.toUpperCase().includes('PREESCOLAR'));

        if (grupo.materias) {
          const curriculares = grupo.materias.filter((m: any) => m.tipo === 'curricular' || !m.tipo);
          setMaterias(curriculares);
          // Auto-select first subject if available
          if (curriculares.length > 0) {
            setMateriaSeleccionadaId(String(curriculares[0].id || curriculares[0].grupoMateriaId));
          } else {
            setMateriaSeleccionadaId('');
            setAlumnos([]);
            setGrid({});
          }
        }
      } catch (err) {
        console.error('Error fetching grupo details:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchGrupoDetails();
  }, [grupoSeleccionadoId]);

  // 3. When a subject is selected (and we have a group), fetch students and their grades
  useEffect(() => {
    if (!grupoSeleccionadoId || !materiaSeleccionadaId) {
      setAlumnos([]);
      setGrid({});
      return;
    }

    const fetchAlumnosYCalificaciones = async () => {
      setLoading(true);
      try {
        // Fetch students in the group
        const resA: any = await alumnosService.getAlumnos({ grupoId: grupoSeleccionadoId, limit: 200 });
        const listAlumnos = resA.data?.data || resA.data || resA;
        // Sort alphabetically
        listAlumnos.sort((a: any, b: any) => a.nombre?.localeCompare(b.nombre));
        setAlumnos(listAlumnos);

        // Fetch grades for this specific subject
        const resC: any = await calificacionesService.obtenerPorGrupoMateria(Number(materiaSeleccionadaId));
        const califsList = resC.data?.data || resC.data || resC;

        // Initialize grid
        const newGrid: Record<number, any> = {};
        listAlumnos.forEach((al: any) => {
          newGrid[al.id] = {
            T1: { v: '', t: '' },
            T2: { v: '', t: '' },
            T3: { v: '', t: '' },
            prom: '-'
          };
        });

        // Populate existing grades
        if (Array.isArray(califsList)) {
          califsList.forEach((c: any) => {
            if (newGrid[c.alumnoId]) {
              const k = String(c.periodo).includes('1') ? 'T1' : String(c.periodo).includes('2') ? 'T2' : 'T3';
              newGrid[c.alumnoId][k].v = c.valor !== null ? c.valor : '';
              newGrid[c.alumnoId][k].t = c.textoObservacion || '';
            }
          });
        }

        // Calculate initial averages
        Object.keys(newGrid).forEach(key => {
          recalcularPromedioAlumno(newGrid[Number(key)], esPreescolar);
        });

        setGrid(newGrid);
      } catch (err) {
        console.error('Error fetching students or grades:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchAlumnosYCalificaciones();
  }, [grupoSeleccionadoId, materiaSeleccionadaId, esPreescolar]);

  // Helper to calculate average for a single student row
  const recalcularPromedioAlumno = (row: any, isPre: boolean) => {
    if (isPre) {
      row.prom = 'N/A';
      return;
    }
    let s = 0, c = 0;
    ['T1', 'T2', 'T3'].forEach(t => {
      if (row[t].v !== '') {
        let v = parseFloat(row[t].v);
        if (v > 10) { row[t].v = 10; v = 10; }
        if (v < 0) { row[t].v = 0; v = 0; }
        s += v; c++;
      }
    });
    row.prom = c > 0 ? (s / c).toFixed(1) : '-';
  };

  // Handle cell change
  const handleCellChange = (alumnoId: number, trim: string, field: 'v'|'t', value: string) => {
    setGrid(prev => {
      const newGrid = { ...prev };
      const row = { ...newGrid[alumnoId] };
      row[trim] = { ...row[trim], [field]: value };
      recalcularPromedioAlumno(row, esPreescolar);
      newGrid[alumnoId] = row;
      return newGrid;
    });
  };

  // Save all grades
  const guardarCalificaciones = async () => {
    const lote: any[] = [];
    const periodos = ['TRIMESTRE_1', 'TRIMESTRE_2', 'TRIMESTRE_3'];
    
    Object.keys(grid).forEach(alId => {
      const row = grid[Number(alId)];
      ['T1', 'T2', 'T3'].forEach((t, i) => {
        if (esPreescolar) {
          const obs = row[t].t?.trim();
          if (obs) {
            lote.push({ 
              alumnoId: Number(alId), 
              grupoMateriaId: Number(materiaSeleccionadaId), 
              periodo: periodos[i], 
              valor: null, 
              textoObservacion: obs, 
              tipoEvaluacion: 'observacion' 
            });
          }
        } else {
          const valStr = row[t].v;
          if (valStr !== '') {
            const val = parseFloat(valStr);
            if (!isNaN(val) && val >= 0 && val <= 10) {
              lote.push({ 
                alumnoId: Number(alId), 
                grupoMateriaId: Number(materiaSeleccionadaId), 
                periodo: periodos[i], 
                valor: val, 
                tipoEvaluacion: 'numerica' 
              });
            }
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
      await calificacionesService.guardarLote(lote);
      alert('Calificaciones guardadas correctamente.');
    } catch (error) {
      console.error('Error guardando', error);
      alert('Error al guardar calificaciones');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="h-full flex flex-col relative overflow-hidden">
      {/* Header */}
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-navy-800 flex items-center gap-2">
          <Award className="text-navy-600" /> Sábana de Calificaciones
        </h2>
        <p className="text-sm text-gray-500 mt-1">Selecciona un grupo y una materia para evaluar a todo el salón.</p>
      </div>

      {/* Selectors */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 mb-6 flex flex-col md:flex-row gap-4">
        <div className="flex-1">
          <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">1. Seleccionar Grupo</label>
          <select 
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none font-medium text-gray-700 bg-gray-50"
            value={grupoSeleccionadoId}
            onChange={(e) => setGrupoSeleccionadoId(e.target.value)}
          >
            <option value="">-- Elige un grupo --</option>
            {grupos.map((g: any) => (
              <option key={g.id} value={g.id}>
                {g.grado}° {g.seccion} {g.nivel?.codigo || g.nivel} ({g.cicloEscolar?.nombre || g.cicloId})
              </option>
            ))}
          </select>
        </div>

        <div className="flex-[2]">
          <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">2. Seleccionar Materia</label>
          {materias.length === 0 ? (
            <div className="px-4 py-2.5 rounded-xl border border-dashed border-gray-300 text-gray-400 bg-gray-50 text-sm flex items-center gap-2">
              <BookOpen size={16} /> Primero selecciona un grupo con materias asignadas.
            </div>
          ) : (
            <select 
              className="w-full px-4 py-2.5 rounded-xl border border-navy-200 focus:ring-2 focus:ring-navy-500 outline-none font-medium text-navy-700 bg-navy-50"
              value={materiaSeleccionadaId}
              onChange={(e) => setMateriaSeleccionadaId(e.target.value)}
            >
              <option value="">-- Elige una materia --</option>
              {materias.map((m: any) => (
                <option key={m.id || m.grupoMateriaId} value={m.id || m.grupoMateriaId}>
                  {m.materia || m.nombre}
                </option>
              ))}
            </select>
          )}
        </div>
      </div>

      {/* Main Grid */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 flex flex-col overflow-hidden">
        <div className="border-b border-gray-100 px-6 py-4 flex items-center justify-between bg-gray-50">
          <h3 className="font-bold text-gray-800">
            Captura de Evaluaciones
          </h3>
          <div className="flex items-center gap-3">
            <span className="text-xs font-medium text-gray-500 bg-white px-3 py-1 rounded-full border border-gray-200 shadow-sm">
              {alumnos.length} Alumnos
            </span>
          </div>
        </div>

        <div className="flex-1 overflow-auto p-0 relative">
          {loading ? (
            <div className="absolute inset-0 bg-white/60 flex items-center justify-center z-10 backdrop-blur-[1px]">
              <div className="w-8 h-8 border-2 border-navy-500 border-t-transparent rounded-full animate-spin" />
            </div>
          ) : null}

          {(!grupoSeleccionadoId || !materiaSeleccionadaId) ? (
            <div className="h-full flex flex-col items-center justify-center text-gray-400 p-8">
              <Search className="w-12 h-12 mb-3 text-gray-200" />
              <p>Selecciona un grupo y materia para comenzar a calificar.</p>
            </div>
          ) : alumnos.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-gray-400 p-8">
              <AlertCircle className="w-12 h-12 mb-3 text-gray-200" />
              <p>El grupo seleccionado no tiene alumnos inscritos.</p>
            </div>
          ) : (
            <table className="w-full text-sm text-left">
              <thead className="bg-gray-100/50 text-gray-600 sticky top-0 z-10 backdrop-blur-md">
                <tr>
                  <th className="p-4 font-semibold w-8 text-center text-gray-400">#</th>
                  <th className="p-4 font-semibold min-w-[200px]">Alumno</th>
                  <th className="p-4 font-semibold text-center w-32 md:w-48">Trimestre 1</th>
                  <th className="p-4 font-semibold text-center w-32 md:w-48">Trimestre 2</th>
                  <th className="p-4 font-semibold text-center w-32 md:w-48">Trimestre 3</th>
                  {!esPreescolar && (
                    <th className="p-4 font-semibold text-center w-24">Prom.</th>
                  )}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {alumnos.map((al, index) => {
                  const row = grid[al.id] || { T1:{v:'', t:''}, T2:{v:'', t:''}, T3:{v:'', t:''}, prom:'-' };
                  return (
                    <tr key={al.id} className="hover:bg-blue-50/30 transition-colors group">
                      <td className="p-4 text-center text-xs text-gray-400 font-medium">
                        {index + 1}
                      </td>
                      <td className="p-4">
                        <div className="font-bold text-gray-800">{al.nombre}</div>
                        <div className="text-xs text-gray-400 font-mono mt-0.5">{al.matricula}</div>
                      </td>
                      
                      {['T1', 'T2', 'T3'].map((trim: any) => (
                        <td key={trim} className="p-2 md:p-4 align-top">
                          {esPreescolar ? (
                            <textarea 
                              className="w-full bg-white border border-gray-200 rounded-lg p-2.5 text-xs h-16 resize-none focus:ring-2 focus:ring-navy-500 focus:border-navy-500 outline-none transition-all"
                              placeholder={`Obs. ${trim}...`}
                              value={row[trim].t}
                              onChange={(e) => handleCellChange(al.id, trim, 't', e.target.value)}
                            />
                          ) : (
                            <input 
                              type="number" 
                              min="0" max="10" step="0.1"
                              placeholder="-"
                              className="w-full bg-white border border-gray-200 rounded-xl p-2.5 text-center focus:ring-2 focus:ring-navy-500 focus:border-navy-500 outline-none transition-all font-semibold text-gray-700"
                              value={row[trim].v}
                              onChange={(e) => handleCellChange(al.id, trim, 'v', e.target.value)}
                            />
                          )}
                        </td>
                      ))}

                      {!esPreescolar && (
                        <td className="p-4 text-center align-middle">
                          <span className={`font-bold px-3 py-1.5 rounded-xl text-xs inline-block min-w-[3rem] ${
                            row.prom === 'N/A' || row.prom === '-' ? 'text-gray-400 bg-gray-100' :
                            parseFloat(row.prom) < 6 ? 'text-red-700 bg-red-50 border border-red-100' : 'text-emerald-700 bg-emerald-50 border border-emerald-100'
                          }`}>
                            {row.prom}
                          </span>
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>

        {/* Footer actions */}
        <div className="p-5 border-t border-gray-100 bg-white flex justify-end">
          <button 
            onClick={guardarCalificaciones} 
            disabled={saving || !grupoSeleccionadoId || !materiaSeleccionadaId || alumnos.length === 0}
            className="flex items-center gap-2 px-8 py-3 bg-navy-600 text-white rounded-xl hover:bg-navy-700 transition-all shadow-md hover:shadow-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed active:scale-95"
          >
            {saving ? (
              <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <Save size={18} />
            )}
            {saving ? 'Guardando...' : 'Guardar Toda la Sábana'}
          </button>
        </div>
      </div>
    </div>
  );
}
