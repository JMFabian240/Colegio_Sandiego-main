import React, { useState, useEffect, useCallback } from 'react';
import { ArrowLeft, Printer, FolderOpen, Search } from 'lucide-react';
import api from '../services/api';

// ─── Types ────────────────────────────────────────────────────────────────────

interface AlumnoResumen {
  id: number;
  nombre: string;
  matricula?: string;
  nivel?: string;
  grado?: number | string;
  grupoActual?: string;
}

interface CurricularPromedio {
  materia: string;
  periodo: string;
  promedio: string;
  tipoEvaluacion?: string;
}

interface TallerItem {
  taller: string;
  periodo: string;
  valorCualitativo?: string;
}

interface ExtracurricularItem {
  club: string;
  periodo: string;
  valorNumerico?: string | number;
}

interface RegistroCiclo {
  ciclo: { cicloId: number; nombre: string };
  curriculares: CurricularPromedio[];
  talleres: TallerItem[];
  extracurriculares: ExtracurricularItem[];
}

// ─── Helper: formatear respuesta de la API ───────────────────────────────────

function formatearHistorial(historialRaw: any[]): RegistroCiclo[] {
  return historialRaw.map((ciclo: any) => {
    const matMap: Record<string, any> = {};
    (ciclo.curriculares ?? []).forEach((c: any) => {
      if (!matMap[c.materia]) {
        matMap[c.materia] = {
          materia: c.materia,
          periodo: ciclo.ciclo.nombre,
          suma: 0,
          conteo: 0,
          valorCualitativo: c.valorCualitativo,
          tipoEvaluacion: c.tipoEvaluacion,
        };
      }
      if (c.tipoEvaluacion === 'numerica' && c.valorNumerico !== null) {
        matMap[c.materia].suma += parseFloat(c.valorNumerico);
        matMap[c.materia].conteo += 1;
      }
    });

    const curriculares: CurricularPromedio[] = Object.values(matMap).map((m: any) => ({
      materia: m.materia,
      periodo: m.periodo,
      tipoEvaluacion: m.tipoEvaluacion,
      promedio:
        m.tipoEvaluacion === 'numerica'
          ? m.conteo > 0
            ? (m.suma / m.conteo).toFixed(1)
            : '-'
          : m.valorCualitativo || '-',
    }));

    const talleresSet: Record<string, TallerItem> = {};
    (ciclo.talleres ?? []).forEach((t: any) => {
      talleresSet[t.taller] = {
        taller: t.taller,
        periodo: ciclo.ciclo.nombre,
        valorCualitativo: t.valorCualitativo,
      };
    });

    const extraSet: Record<string, ExtracurricularItem> = {};
    (ciclo.extracurriculares ?? []).forEach((ex: any) => {
      extraSet[ex.club] = {
        club: ex.club,
        periodo: ciclo.ciclo.nombre,
        valorNumerico: ex.valorNumerico,
      };
    });

    return {
      ciclo: ciclo.ciclo,
      curriculares,
      talleres: Object.values(talleresSet),
      extracurriculares: Object.values(extraSet),
    };
  });
}

// ─── Sub-component: tabla genérica de historial ──────────────────────────────

function TablaHistorial({
  headers,
  rows,
}: {
  headers: string[];
  rows: React.ReactNode[][];
}) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left text-sm text-gray-700">
        <thead className="bg-gray-100 text-gray-600 uppercase text-xs">
          <tr>
            {headers.map((h, i) => (
              <th
                key={i}
                className={`px-4 py-2 ${i === 0 ? 'rounded-tl' : ''} ${
                  i === headers.length - 1 ? 'rounded-tr text-center' : ''
                }`}
              >
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {rows.map((row, ri) => (
            <tr key={ri} className="hover:bg-gray-50/50">
              {row.map((cell, ci) => (
                <td
                  key={ci}
                  className={`px-4 py-2 ${ci === 0 ? 'font-medium text-gray-900' : ''} ${
                    ci === row.length - 1 ? 'text-center font-bold' : ''
                  }`}
                >
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ─── Main component ───────────────────────────────────────────────────────────

export function HistorialAcademico() {
  const [listaAlumnos, setListaAlumnos] = useState<AlumnoResumen[]>([]);
  const [loadingLista, setLoadingLista] = useState(false);

  const [busqueda, setBusqueda] = useState('');
  const [filtroNivel, setFiltroNivel] = useState('');
  const [filtroGrado, setFiltroGrado] = useState('');
  const [filtroGrupo, setFiltroGrupo] = useState('');

  const [alumnoSeleccionado, setAlumnoSeleccionado] = useState<AlumnoResumen | null>(null);
  const [historial, setHistorial] = useState<RegistroCiclo[]>([]);
  const [loadingHistorial, setLoadingHistorial] = useState(false);
  const [errorHistorial, setErrorHistorial] = useState('');

  const nivelesDisponibles = ['PREESCOLAR', 'PRIMARIA', 'SECUNDARIA', 'BACHILLERATO'];
  const gradosList = ['1', '2', '3', '4', '5', '6'];
  const gruposList = ['A', 'B', 'C', 'D', 'E', 'F'];

  // Cargar lista de alumnos al montar
  useEffect(() => {
    const fetchAlumnos = async () => {
      setLoadingLista(true);
      try {
        const res: any = await api.get('/alumnos', { params: { limit: 500 } });
        const payload = res.data?.data || res.data || [];
        setListaAlumnos(Array.isArray(payload) ? payload : (payload.alumnos ?? []));
      } catch (err) {
        console.error('Error cargando alumnos:', err);
      } finally {
        setLoadingLista(false);
      }
    };
    fetchAlumnos();
  }, []);

  // Filtrar lista localmente
  const resultados: AlumnoResumen[] = listaAlumnos.filter((al) => {
    const q = busqueda.trim().toLowerCase();
    const matchQ =
      !q ||
      al.nombre.toLowerCase().includes(q) ||
      (al.matricula && al.matricula.toLowerCase().includes(q));
    const matchNivel =
      !filtroNivel || (al.nivel && al.nivel.toUpperCase() === filtroNivel.toUpperCase());
    const matchGrado = !filtroGrado || String(al.grado) === filtroGrado;
    const matchGrupo =
      !filtroGrupo ||
      (al.grupoActual && al.grupoActual.toUpperCase() === filtroGrupo.toUpperCase());
    return matchQ && matchNivel && matchGrado && matchGrupo;
  });

  // Seleccionar alumno y cargar su historial
  const seleccionarAlumno = useCallback(async (al: AlumnoResumen) => {
    setAlumnoSeleccionado(al);
    setHistorial([]);
    setErrorHistorial('');
    setLoadingHistorial(true);
    try {
      const res: any = await api.get(`/alumnos/${al.id}/historial-academico`);
      const payload = res.data ?? res;
      const rawHistorial = payload.historial ?? payload;
      setHistorial(Array.isArray(rawHistorial) ? formatearHistorial(rawHistorial) : []);
    } catch (err: any) {
      setErrorHistorial(
        err?.response?.data?.message || err?.message || 'Error al cargar historial.'
      );
    } finally {
      setLoadingHistorial(false);
    }
  }, []);

  const volver = () => {
    setAlumnoSeleccionado(null);
    setHistorial([]);
    setErrorHistorial('');
  };

  // ── Vista: lista de alumnos ──────────────────────────────────────────────
  if (!alumnoSeleccionado) {
    return (
      <div className="space-y-6">
        <h2 className="text-xl font-bold text-gray-800">Historial Académico Completo</h2>

        {/* Filtros */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Alumno</label>
            <div className="relative">
              <Search className="absolute left-2.5 top-2.5 w-4 h-4 text-gray-400" />
              <input
                type="text"
                className="w-full border border-gray-300 rounded-lg pl-8 pr-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Nombre o matrícula..."
                value={busqueda}
                onChange={(e) => setBusqueda(e.target.value)}
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Nivel Escolar</label>
            <select
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              value={filtroNivel}
              onChange={(e) => {
                setFiltroNivel(e.target.value);
                setFiltroGrado('');
                setFiltroGrupo('');
              }}
            >
              <option value="">Todos los niveles</option>
              {nivelesDisponibles.map((n) => (
                <option key={n} value={n}>{n}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Grado</label>
            <select
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
              value={filtroGrado}
              disabled={!filtroNivel}
              onChange={(e) => {
                setFiltroGrado(e.target.value);
                setFiltroGrupo('');
              }}
            >
              <option value="">Grado</option>
              {gradosList.map((g) => (
                <option key={g} value={g}>{g}°</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Grupo</label>
            <select
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
              value={filtroGrupo}
              disabled={!filtroGrado}
              onChange={(e) => setFiltroGrupo(e.target.value)}
            >
              <option value="">Grupo</option>
              {gruposList.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Tabla */}
        <div className="bg-white border border-gray-200 rounded-xl overflow-hidden shadow-sm">
          {loadingLista ? (
            <div className="p-8 text-center text-gray-500">Cargando alumnos...</div>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="p-3 text-left font-semibold text-gray-700">Alumno</th>
                  <th className="p-3 text-left font-semibold text-gray-700">Nivel</th>
                  <th className="p-3 text-left font-semibold text-gray-700">Grado y Grupo</th>
                  <th className="p-3 text-right font-semibold text-gray-700">Acciones</th>
                </tr>
              </thead>
              <tbody>
                {resultados.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="p-8 text-center text-gray-500">
                      No se encontraron alumnos con los criterios especificados.
                    </td>
                  </tr>
                ) : (
                  resultados.map((al) => (
                    <tr
                      key={al.id}
                      className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                    >
                      <td className="p-3">
                        <div className="font-medium text-gray-900">{al.nombre}</div>
                        <div className="text-xs text-gray-500">
                          Matrícula: {al.matricula || 'S/M'}
                        </div>
                      </td>
                      <td className="p-3 text-gray-700">{al.nivel || 'N/A'}</td>
                      <td className="p-3 text-gray-700">
                        {al.grado ? `${al.grado}° ` : ''}{al.grupoActual || ''}
                      </td>
                      <td className="p-3 text-right">
                        <button
                          onClick={() => seleccionarAlumno(al)}
                          className="px-3 py-1 text-xs border border-blue-600 text-blue-600 rounded-lg hover:bg-blue-50 transition-colors font-medium"
                        >
                          Ver Historial
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}
        </div>
      </div>
    );
  }

  // ── Vista: historial del alumno ──────────────────────────────────────────
  return (
    <div className="space-y-6" id="historialAcademicoImprimible">
      {/* Botón volver */}
      <div className="print:hidden">
        <button
          onClick={volver}
          className="flex items-center gap-2 px-3 py-1.5 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Volver a la lista
        </button>
      </div>

      {/* Header institucional */}
      <div className="bg-blue-900 text-white rounded-xl p-6 md:p-8 shadow-lg relative">
        <div className="absolute top-6 right-6 print:hidden">
          <button
            onClick={() => window.print()}
            className="flex items-center gap-2 px-3 py-2 border border-white/40 rounded-lg hover:bg-white/10 transition-colors text-sm"
          >
            <Printer className="w-4 h-4" />
            Imprimir
          </button>
        </div>

        <div className="grid grid-cols-[90px_1fr] gap-x-4 gap-y-3 text-sm text-white/80 pr-36">
          <div className="font-bold text-white/60">Alumno:</div>
          <div className="uppercase text-white">
            <span className="font-bold mr-6">{alumnoSeleccionado.matricula || 'S/M'}</span>
            <span>{alumnoSeleccionado.nombre}</span>
          </div>

          <div className="font-bold text-white/60">Programa:</div>
          <div className="uppercase text-white">
            EDUCACIÓN BÁSICA — {alumnoSeleccionado.nivel || ''}
          </div>

          <div className="font-bold text-white/60">Campus:</div>
          <div className="uppercase flex flex-wrap gap-x-8 gap-y-2 text-white">
            <span>COLEGIO SAN DIEGO</span>
            <span>
              <span className="font-bold text-white/60">Modalidad:</span> ESCOLARIZADO
            </span>
            <span>
              <span className="font-bold text-white/60">Nivel:</span>{' '}
              {alumnoSeleccionado.nivel || ''}
            </span>
          </div>
        </div>

        <p className="text-center italic text-white/50 text-xs mt-8">
          "Los datos que se presentan son únicamente de carácter informativo y carecen de validez oficial."
        </p>
      </div>

      {/* Loading / error */}
      {loadingHistorial && (
        <div className="bg-white border border-gray-200 rounded-xl p-8 text-center text-gray-500">
          Cargando historial académico...
        </div>
      )}
      {errorHistorial && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-4 text-red-700 text-sm">
          {errorHistorial}
        </div>
      )}

      {/* Sin historial */}
      {!loadingHistorial && !errorHistorial && historial.length === 0 && (
        <div className="bg-white border border-gray-200 rounded-xl p-8 text-center text-gray-500">
          <FolderOpen className="w-12 h-12 mx-auto mb-3 opacity-40" />
          <p>El alumno no cuenta con historial académico registrado.</p>
        </div>
      )}

      {/* Ciclos escolares */}
      {historial.map((registro) => (
        <div
          key={registro.ciclo.cicloId}
          className="bg-white border border-gray-200 border-l-4 border-l-blue-700 rounded-xl overflow-hidden shadow-sm print:break-inside-avoid print:shadow-none print:border-gray-300"
        >
          <div className="bg-gray-50 px-6 py-4 border-b border-gray-100">
            <h3 className="font-bold text-lg text-gray-800 uppercase">
              Ciclo Escolar {registro.ciclo.nombre}
            </h3>
          </div>

          <div className="p-6 space-y-8">
            {/* Curriculares */}
            {registro.curriculares.length > 0 && (
              <div>
                <h4 className="font-bold text-blue-800 border-b border-gray-200 pb-2 mb-4 text-xs tracking-wider uppercase">
                  Área de Formación Curricular
                </h4>
                <TablaHistorial
                  headers={['Experiencia Educativa', 'Periodo', 'Calificación']}
                  rows={registro.curriculares.map((c) => [
                    c.materia,
                    c.periodo,
                    <span
                      className={
                        !isNaN(Number(c.promedio)) && Number(c.promedio) < 6
                          ? 'text-red-600'
                          : 'text-emerald-700'
                      }
                    >
                      {c.promedio}
                    </span>,
                  ])}
                />
              </div>
            )}

            {/* Talleres */}
            {registro.talleres.length > 0 && (
              <div>
                <h4 className="font-bold text-blue-800 border-b border-gray-200 pb-2 mb-4 text-xs tracking-wider uppercase">
                  Talleres Formativos
                </h4>
                <TablaHistorial
                  headers={['Taller', 'Periodo', 'Evaluación']}
                  rows={registro.talleres.map((t) => [
                    t.taller,
                    t.periodo,
                    t.valorCualitativo || '-',
                  ])}
                />
              </div>
            )}

            {/* Extracurriculares */}
            {registro.extracurriculares.length > 0 && (
              <div>
                <h4 className="font-bold text-blue-800 border-b border-gray-200 pb-2 mb-4 text-xs tracking-wider uppercase">
                  Clubes Extracurriculares
                </h4>
                <TablaHistorial
                  headers={['Club / Actividad', 'Periodo', 'Evaluación']}
                  rows={registro.extracurriculares.map((ex) => [
                    <span className="capitalize">{ex.club}</span>,
                    ex.periodo,
                    String(ex.valorNumerico ?? '-'),
                  ])}
                />
              </div>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
