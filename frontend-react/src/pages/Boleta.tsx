import React, { useState, useEffect } from 'react';
import { FileText, Download, Search, ArrowLeft } from 'lucide-react';
import { jsPDF } from 'jspdf';
import { alumnosService } from '../services/alumnos.service';

// ─── Types ────────────────────────────────────────────────────────────────────

interface AlumnoResumen {
  id: number;
  nombre: string;
  matricula?: string;
  curp?: string;
  nivel?: string;
  turno?: string;
  grado?: string | number;
  grupoActual?: string;
  grupo?: { nombre?: string; codigo?: string; cct?: string; grado?: string | number };
}

interface Calificacion {
  nombre: string;
  T1: { v: string };
  T2: { v: string };
  T3: { v: string };
  prom?: string;
}

function exportarBoletaPDF(
  alumno: AlumnoResumen,
  calificaciones: Calificacion[],
  promedioGeneral: string
) {

  const nivel = (alumno.nivel || '').toUpperCase();
  const nombre = alumno.nombre || 'N/A';
  const curp = alumno.curp || 'N/A';
  const matricula = alumno.matricula || 'N/A';
  const grado = String(alumno.grado || alumno.grupo?.grado || '');
  const grupo = alumno.grupoActual || alumno.grupo?.nombre || alumno.grupo?.codigo || '';
  const turno = alumno.turno || 'MATUTINO';
  const ctt = alumno.grupo?.cct || '30PPR3773B';
  const hoy = new Date();
  const dia = String(hoy.getDate()).padStart(2, '0');
  const mes = String(hoy.getMonth() + 1).padStart(2, '0');
  const anio = hoy.getFullYear();

  // Helpers PDF
  const fillCell = (doc: any, x: number, y: number, w: number, h: number, r: number, g: number, b: number) => {
    doc.setFillColor(r, g, b);
    doc.rect(x, y, w, h, 'F');
    doc.setFillColor(255, 255, 255);
  };

  const drawCell = (doc: any, x: number, y: number, w: number, h: number, text: string, opts: any = {}) => {
    doc.rect(x, y, w, h);
    doc.setFontSize(opts.fontSize || 8);
    doc.setFont(undefined, opts.bold ? 'bold' : 'normal');
    doc.setTextColor(...(opts.color || [0, 0, 0]));
    doc.text(
      String(text || ''),
      opts.align === 'center' ? x + w / 2 : x + 1.5,
      y + h / 2 + 0.5,
      { align: opts.align || 'left', baseline: 'middle' }
    );
    doc.setTextColor(0, 0, 0);
    doc.setFont(undefined, 'normal');
  };

  const hdrBlue = (doc: any, x: number, y: number, w: number, h: number, text: string, fs = 7) => {
    fillCell(doc, x, y, w, h, 30, 85, 160);
    doc.setFontSize(fs);
    doc.setFont(undefined, 'bold');
    doc.setTextColor(255, 255, 255);
    doc.text(text, x + w / 2, y + h / 2 + 0.5, { align: 'center', baseline: 'middle' });
    doc.setTextColor(0, 0, 0);
    doc.setFont(undefined, 'normal');
  };

  const PW = 215.9, M = 10;
  const letras = ['CERO','UNO','DOS','TRES','CUATRO','CINCO','SEIS','SIETE','OCHO','NUEVE','DIEZ'];

  if (nivel === 'BACHILLERATO') {
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'letter' });
    let y = M;

    fillCell(doc, M, y, PW - 2 * M, 7, 200, 30, 30);
    doc.setFontSize(10); doc.setFont(undefined, 'bold'); doc.setTextColor(255, 255, 255);
    doc.text('DATOS DEL EDUCANDO', PW / 2, y + 3.5, { align: 'center', baseline: 'middle' });
    doc.setTextColor(0, 0, 0); y += 7;

    const H1 = 6;
    const cols1 = [
      { l: 'NOMBRE', w: 55 }, { l: 'CURP', w: 38 }, { l: 'SEMESTRE', w: 25 },
      { l: 'GRUPO', w: 20 }, { l: 'PERIODO ESCOLAR', w: 52 },
    ];
    let cx = M;
    cols1.forEach((c) => {
      fillCell(doc, cx, y, c.w, H1, 200, 210, 230);
      doc.rect(cx, y, c.w, H1);
      doc.setFontSize(6.5); doc.setFont(undefined, 'bold');
      doc.text(c.l, cx + c.w / 2, y + H1 / 2 + 0.5, { align: 'center', baseline: 'middle' });
      cx += c.w;
    });
    y += H1; cx = M;
    [nombre, curp, grado || 'V', grupo || 'B', `${anio - 1}-${anio}`].forEach((v, i) => {
      const ws = [55, 38, 25, 20, 52][i];
      doc.rect(cx, y, ws, 8); doc.setFontSize(6.5); doc.setFont(undefined, 'bold');
      doc.setTextColor(20, 80, 180);
      const textVal = String(v);
      const printVal = textVal.length > 32 ? textVal.substring(0, 32) : textVal;
      doc.text(printVal, cx + ws / 2, y + 4, { align: 'center', baseline: 'middle' });
      doc.setTextColor(0, 0, 0); cx += ws;
    });
    y += 8;

    const rH = 5.5;
    calificaciones.forEach((mat) => {
      const vs = [mat.T1.v, mat.T2.v, mat.T3.v].map((v) => (v !== '' ? parseFloat(v) : null));
      const valid = vs.filter((v) => v !== null) as number[];
      const prom = valid.length > 0 ? (valid.reduce((a, b) => a + b, 0) / valid.length).toFixed(1) : '-';
      const pN = prom !== '-' ? Math.round(parseFloat(prom)) : null;
      const letra = pN !== null && pN >= 0 && pN <= 10 ? letras[pN] : '-';
      const maxSubject = mat.nombre.length > 42 ? mat.nombre.substring(0, 42) : mat.nombre;
      drawCell(doc, M, y, 55, rH, maxSubject.toUpperCase(), { fontSize: 5.5 });
      vs.forEach((v, i) =>
        drawCell(doc, 93 + i * 13.5, y, 13.5, rH, v !== null ? String(v) : '-', { align: 'center', fontSize: 7 })
      );
      drawCell(doc, 93 + 3 * 13.5, y, 13.5, rH, prom, { align: 'center', fontSize: 7, bold: true });
      drawCell(doc, 147, y, 17.5, rH, prom, { align: 'center', fontSize: 7 });
      drawCell(doc, 164.5, y, 17.5, rH, letra, { align: 'center', fontSize: 7, bold: true });
      drawCell(doc, 182, y, 24, rH, 'P', { align: 'center', fontSize: 7 });
      y += rH;
    });
    doc.save(`Boleta_Bachillerato_${matricula}.pdf`);

  } else if (nivel === 'PREESCOLAR') {
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'letter' });
    let y = M;
    doc.setFontSize(9); doc.setFont(undefined, 'bold');
    doc.text('"CENTRO DE INVESTIGACION EDUCATIVA"', PW / 2, y, { align: 'center' }); y += 5;
    doc.text('COLEGIO SAN DIEGO', PW / 2, y, { align: 'center' }); y += 4;
    doc.setFont(undefined, 'normal'); doc.setFontSize(7.5);
    doc.text('Calle punta el campanario #183 Col. Bahia de San Martín', PW / 2, y, { align: 'center' }); y += 4;
    doc.text('PREESCOLAR', PW / 2, y, { align: 'center' }); y += 4;
    doc.text(ctt, PW / 2, y, { align: 'center' }); y += 8;
    doc.setFontSize(10); doc.setFont(undefined, 'bold');
    doc.text('BOLETA DE EVALUACION', PW / 2, y, { align: 'center' }); y += 7;
    doc.setFontSize(8); doc.setFont(undefined, 'bold');
    doc.text('DATOS DEL ALUMNO (A):', M, y); y += 5;
    doc.setFont(undefined, 'normal');
    doc.text(`Nombre: ${nombre}`, M + 5, y); y += 4;
    doc.text(`CURP: ${curp}`, M + 5, y); y += 4;
    doc.text(`Fecha: ${dia}/${mes}/${anio}`, M + 5, y);
    doc.save(`Boleta_Preescolar_${matricula}.pdf`);

  } else {
    // Primaria / Secundaria
    const esSecundaria = nivel === 'SECUNDARIA';
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'letter' });
    let y = M;
    doc.setFontSize(9); doc.setFont(undefined, 'bold');
    doc.text('CENTRO DE INVESTIGACIÓN EDUCATIVA COLEGIO SAN DIEGO', PW / 2, y, { align: 'center' }); y += 5;
    doc.setFont(undefined, 'normal'); doc.setFontSize(7.5);
    doc.text('Punta el Campanario #183 Col. Bahía de San Martín', PW / 2, y, { align: 'center' }); y += 4;
    doc.text(esSecundaria ? `Nivel Secundaria ${ctt}` : 'Nivel Primaria', PW / 2, y, { align: 'center' }); y += 5;
    doc.setFontSize(9); doc.setFont(undefined, 'bold');
    doc.text('BOLETA INTERNA DE CALIFICACIONES', PW / 2, y, { align: 'center' }); y += 9;

    const aW = esSecundaria ? 50 : 55;
    const trimW = esSecundaria ? 35 : 33;
    const promW = 20;
    hdrBlue(doc, M, y, aW, 6, 'ASIGNATURAS');
    ['1er. Trimestre', '2do. Trimestre', '3er. Trimestre'].forEach((t, i) =>
      hdrBlue(doc, M + aW + i * trimW, y, trimW, 6, t)
    );
    hdrBlue(doc, M + aW + 3 * trimW, y, promW, 6, 'Promedio Final');
    y += 6;

    const rH = 8;
    calificaciones.forEach((mat) => {
      const t1 = mat.T1.v !== '' ? mat.T1.v : '-';
      const t2 = mat.T2.v !== '' ? mat.T2.v : '-';
      const t3 = mat.T3.v !== '' ? mat.T3.v : '-';
      const pr = mat.prom || '-';
      const low = pr !== '-' && pr !== 'N/A' && parseFloat(pr) < 6;

      doc.rect(M, y, aW, rH);
      doc.setFontSize(7); doc.setFont(undefined, 'normal');
      doc.text(mat.nombre.toUpperCase().substring(0, 28), M + 1.5, y + rH / 2 + 0.5, { baseline: 'middle' });

      [t1, t2, t3].forEach((v, i) => {
        doc.rect(M + aW + i * trimW, y, trimW, rH);
        doc.setFontSize(9); doc.setFont(undefined, 'bold');
        doc.setTextColor(v !== '-' ? 20 : 100, v !== '-' ? 80 : 100, v !== '-' ? 180 : 100);
        doc.text(String(v), M + aW + i * trimW + trimW / 2, y + rH / 2 + 0.5, { align: 'center', baseline: 'middle' });
      });

      doc.setTextColor(low ? 200 : 0, low ? 30 : 0, low ? 30 : 0);
      doc.rect(M + aW + 3 * trimW, y, promW, rH);
      doc.setFontSize(9); doc.setFont(undefined, 'bold');
      doc.text(String(pr), M + aW + 3 * trimW + promW / 2, y + rH / 2 + 0.5, { align: 'center', baseline: 'middle' });
      doc.setTextColor(0, 0, 0);
      y += rH;
    });

    y += 22;
    doc.setFontSize(7); doc.setFont(undefined, 'bold');
    doc.text(esSecundaria ? 'NORMA MARIA IBARRA FONSECA' : 'MARIA J. GALINDO TOME', M + 10, y + 9);
    doc.setFont(undefined, 'normal'); doc.setFontSize(6.5);
    doc.text(esSecundaria ? 'NOMBRE Y FIRMA DEL DIRECTOR DEL PLANTEL' : 'NOMBRE Y FIRMA DEL DOCENTE', M + 5, y + 15);

    doc.save(`Boleta_${esSecundaria ? 'Secundaria' : 'Primaria'}_${matricula}.pdf`);
  }
}

// ─── Main component ───────────────────────────────────────────────────────────

export function Boleta() {
  const [listaAlumnos, setListaAlumnos] = useState<AlumnoResumen[]>([]);
  const [loadingLista, setLoadingLista] = useState(false);
  const [busqueda, setBusqueda] = useState('');
  const [filtroNivel, setFiltroNivel] = useState('');

  const [alumnoSeleccionado, setAlumnoSeleccionado] = useState<AlumnoResumen | null>(null);
  const [calificaciones, setCalificaciones] = useState<Calificacion[]>([]);
  const [promedioGeneral, setPromedioGeneral] = useState('-');
  const [loadingCals, setLoadingCals] = useState(false);
  const [generando, setGenerando] = useState(false);

  const nivelesDisponibles = ['PREESCOLAR', 'PRIMARIA', 'SECUNDARIA', 'BACHILLERATO'];

  // Cargar alumnos
  useEffect(() => {
    const fetch = async () => {
      setLoadingLista(true);
      try {
        const res: any = await alumnosService.getAlumnos({ limit: 500 });
        const data = res.data?.data || res.data || [];
        setListaAlumnos(Array.isArray(data) ? data : data.alumnos ?? []);
      } catch (err) {
        console.error(err);
      } finally {
        setLoadingLista(false);
      }
    };
    fetch();
  }, []);

  const resultados = listaAlumnos.filter((al) => {
    const q = busqueda.trim().toLowerCase();
    const matchQ = !q || al.nombre.toLowerCase().includes(q) || (al.matricula?.toLowerCase().includes(q) ?? false);
    const matchN = !filtroNivel || (al.nivel?.toUpperCase() === filtroNivel);
    return matchQ && matchN;
  });

  // Seleccionar alumno y cargar sus calificaciones del último ciclo
  const seleccionar = async (al: AlumnoResumen) => {
    setAlumnoSeleccionado(al);
    setCalificaciones([]);
    setPromedioGeneral('-');
    setLoadingCals(true);
    try {
      const idA = al.id || (al as any).alumnoId;
      const res: any = await alumnosService.obtenerHistorialAcademico(idA);
      const payload = res.data ?? res;
      const historial = payload.historial ?? payload;

      if (Array.isArray(historial) && historial.length > 0) {
        // Tomar el ciclo más reciente
        const ultimoCiclo = historial[historial.length - 1];
        const curriculares = ultimoCiclo?.curriculares ?? [];

        // Agrupar por materia → T1, T2, T3
        const matMap: Record<string, any> = {};
        curriculares.forEach((c: any) => {
          if (!matMap[c.materia]) {
            matMap[c.materia] = { nombre: c.materia, T1: { v: '' }, T2: { v: '' }, T3: { v: '' } };
          }
          const periodo = c.periodoNombre || c.periodo || '';
          if (/1|primer/i.test(periodo)) matMap[c.materia].T1.v = String(c.valorNumerico ?? c.valorCualitativo ?? '');
          else if (/2|segundo/i.test(periodo)) matMap[c.materia].T2.v = String(c.valorNumerico ?? c.valorCualitativo ?? '');
          else if (/3|tercer/i.test(periodo)) matMap[c.materia].T3.v = String(c.valorNumerico ?? c.valorCualitativo ?? '');
          else matMap[c.materia].T1.v = String(c.valorNumerico ?? c.valorCualitativo ?? '');
        });

        const cals: Calificacion[] = Object.values(matMap).map((m: any) => {
          const vals = [m.T1.v, m.T2.v, m.T3.v]
            .map(Number)
            .filter((n) => !isNaN(n) && n > 0);
          const prom = vals.length > 0 ? (vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(1) : '-';
          return { ...m, prom };
        });

        setCalificaciones(cals);

        const todos = cals.map((c) => parseFloat(c.prom ?? '')).filter((n) => !isNaN(n));
        setPromedioGeneral(
          todos.length > 0 ? (todos.reduce((a, b) => a + b, 0) / todos.length).toFixed(1) : '-'
        );
      }
    } catch (err) {
      console.error('Error cargando calificaciones:', err);
    } finally {
      setLoadingCals(false);
    }
  };

  const volver = () => {
    setAlumnoSeleccionado(null);
    setCalificaciones([]);
  };

  const generarPDF = () => {
    if (!alumnoSeleccionado) return;
    setGenerando(true);
    try {
      exportarBoletaPDF(alumnoSeleccionado, calificaciones, promedioGeneral);
    } finally {
      setGenerando(false);
    }
  };

  // ── Vista: lista ──────────────────────────────────────────────────────────
  if (!alumnoSeleccionado) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-xl font-bold text-gray-800">Generación de Boletas</h2>
          <p className="text-sm text-gray-500 mt-1">
            Selecciona un alumno para generar su boleta de calificaciones en PDF.
          </p>
        </div>

        {/* Filtros */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="md:col-span-2">
            <label className="block text-xs font-medium text-gray-600 mb-1">Buscar alumno</label>
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
            <label className="block text-xs font-medium text-gray-600 mb-1">Nivel</label>
            <select
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              value={filtroNivel}
              onChange={(e) => setFiltroNivel(e.target.value)}
            >
              <option value="">Todos los niveles</option>
              {nivelesDisponibles.map((n) => (
                <option key={n} value={n}>{n}</option>
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
                  <th className="p-3 text-left font-semibold text-gray-700">Grado / Grupo</th>
                  <th className="p-3 text-right font-semibold text-gray-700">Acción</th>
                </tr>
              </thead>
              <tbody>
                {resultados.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="p-8 text-center text-gray-500">
                      No se encontraron alumnos.
                    </td>
                  </tr>
                ) : (
                  resultados.map((al) => (
                    <tr key={al.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                      <td className="p-3">
                        <div className="font-medium text-gray-900">{al.nombre}</div>
                        <div className="text-xs text-gray-500">Mat: {al.matricula || 'S/M'}</div>
                      </td>
                      <td className="p-3 text-gray-700">{al.nivel || 'N/A'}</td>
                      <td className="p-3 text-gray-700">
                        {al.grado ? `${al.grado}° ` : ''}{al.grupoActual || ''}
                      </td>
                      <td className="p-3 text-right">
                        <button
                          onClick={() => seleccionar(al)}
                          className="flex items-center gap-1.5 ml-auto px-3 py-1 text-xs border border-blue-600 text-blue-600 rounded-lg hover:bg-blue-50 transition-colors font-medium"
                        >
                          <FileText className="w-3.5 h-3.5" />
                          Generar Boleta
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

  // ── Vista: previsualización y generación ────────────────────────────────
  return (
    <div className="space-y-6">
      {/* Cabecera */}
      <div className="flex items-center justify-between">
        <button
          onClick={volver}
          className="flex items-center gap-2 px-3 py-1.5 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Volver a la lista
        </button>
        <button
          onClick={generarPDF}
          disabled={generando || loadingCals || calificaciones.length === 0}
          className="flex items-center gap-2 px-4 py-2 bg-blue-700 text-white rounded-lg hover:bg-blue-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium"
        >
          <Download className="w-4 h-4" />
          {generando ? 'Generando...' : 'Descargar PDF'}
        </button>
      </div>

      {/* Info alumno */}
      <div className="bg-blue-900 text-white rounded-xl p-6 shadow-lg">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div>
            <div className="text-white/60 text-xs font-semibold uppercase mb-1">Alumno</div>
            <div className="font-bold">{alumnoSeleccionado.nombre}</div>
          </div>
          <div>
            <div className="text-white/60 text-xs font-semibold uppercase mb-1">Matrícula</div>
            <div>{alumnoSeleccionado.matricula || 'S/M'}</div>
          </div>
          <div>
            <div className="text-white/60 text-xs font-semibold uppercase mb-1">Nivel</div>
            <div>{alumnoSeleccionado.nivel || 'N/A'}</div>
          </div>
          <div>
            <div className="text-white/60 text-xs font-semibold uppercase mb-1">Promedio General</div>
            <div className="text-2xl font-bold">{promedioGeneral}</div>
          </div>
        </div>
      </div>

      {/* Tabla de calificaciones (previsualización) */}
      <div className="bg-white border border-gray-200 rounded-xl overflow-hidden shadow-sm">
        <div className="px-6 py-4 border-b border-gray-100 bg-gray-50">
          <h3 className="font-bold text-gray-800">Calificaciones — Ciclo Actual</h3>
        </div>
        {loadingCals ? (
          <div className="p-8 text-center text-gray-500">Cargando calificaciones...</div>
        ) : calificaciones.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            No hay calificaciones registradas para este alumno.
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="p-3 text-left font-semibold text-gray-700">Asignatura</th>
                <th className="p-3 text-center font-semibold text-gray-700">1er Trimestre</th>
                <th className="p-3 text-center font-semibold text-gray-700">2do Trimestre</th>
                <th className="p-3 text-center font-semibold text-gray-700">3er Trimestre</th>
                <th className="p-3 text-center font-semibold text-gray-700">Promedio</th>
              </tr>
            </thead>
            <tbody>
              {calificaciones.map((c, i) => {
                const low = c.prom && c.prom !== '-' && parseFloat(c.prom) < 6;
                return (
                  <tr key={i} className="border-b border-gray-100 hover:bg-gray-50">
                    <td className="p-3 font-medium text-gray-900">{c.nombre}</td>
                    <td className="p-3 text-center text-gray-700">{c.T1.v || '-'}</td>
                    <td className="p-3 text-center text-gray-700">{c.T2.v || '-'}</td>
                    <td className="p-3 text-center text-gray-700">{c.T3.v || '-'}</td>
                    <td className={`p-3 text-center font-bold ${low ? 'text-red-600' : 'text-emerald-700'}`}>
                      {c.prom || '-'}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      <p className="text-xs text-gray-400 text-center">
        La boleta se descarga automáticamente en PDF al hacer clic en "Descargar PDF".
      </p>
    </div>
  );
}
