import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Plus, Phone, Mail, User, Edit2, X, ChevronLeft, ChevronRight, CheckCircle, XCircle, FileText, Download } from 'lucide-react';
import api from '../services/api'; // v2

interface Tutor {
  [key: string]: any;
  tutorId?: number;
  id?: number;
  nombreCompleto?: string;
  correoElectronico?: string;
  telefono?: string;
  rfc?: string;
  curp?: string;
  activo?: boolean;
  alumnos?: any[];
}

const TUTOR_INIT: Partial<Tutor> = {
  nombreCompleto: '',
  correoElectronico: '',
  telefono: '',
  rfc: '',
  curp: '',
  direccion: '',
  requiereFactura: false,
};

export function Tutores() {
  const [tutores, setTutores] = useState<Tutor[]>([]);
  const [loading, setLoading] = useState(false);
  const [busqueda, setBusqueda] = useState('');
  const [pagina, setPagina] = useState(1);
  const [totalPaginas, setTotalPaginas] = useState(1);
  const [total, setTotal] = useState(0);

  const navigate = useNavigate();

  // CRUD modal
  const [modal, setModal] = useState<null | 'crear' | 'editar'>(null);
  const [tutorActual, setTutorActual] = useState<Partial<Tutor>>(TUTOR_INIT);
  const [guardando, setGuardando] = useState(false);
  const [error, setError] = useState('');
  const [filtroFacturantes, setFiltroFacturantes] = useState(false);

  const exportarFacturantes = async () => {
    try {
      const res: any = await api.get('/tutores', { params: { limit: 1000, requiereFactura: true } });
      const lista = Array.isArray(res) ? res : (res.data || []);
      const facturantes = lista.filter((t: any) => t.requiereFactura);
      
      if (facturantes.length === 0) { alert('No hay tutores que requieran factura.'); return; }

      const headers = ['Nombre', 'RFC', 'CURP', 'Régimen Fiscal', 'Uso CFDI', 'Dirección Fiscal', 'Código Postal', 'Correo Facturación', 'Teléfono', 'Alumnos'];
      const rows = facturantes.map((t: any) => [
        t.nombreCompleto || '',
        t.rfc || '',
        t.curp || '',
        t.regimenFiscal || '',
        t.usoCfdi || '',
        t.direccionFiscal || '',
        t.codigoPostal || '',
        t.correoFacturacion || '',
        t.telefono || '',
        (t.alumnos || []).map((a: any) => a.nombre || a.nombreCompleto).join(' | '),
      ]);
      
      const csvContent = [headers, ...rows].map(r => r.map((v: string) => `"${String(v).replace(/"/g, '""')}"`).join(',')).join('\n');
      const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `tutores_facturantes_${new Date().toISOString().slice(0,10)}.csv`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (e) {
      alert('Error al exportar. Intenta de nuevo.');
    }
  };

  const cargarTutores = async () => {
    setLoading(true);
    try {
      const params: any = { page: pagina, limit: 20, q: busqueda };
      if (filtroFacturantes) params.requiereFactura = true;
      const res: any = await api.get('/tutores', { params });
      // api interceptor returns response.data directly
      const lista = Array.isArray(res) ? res : (res.data || []);
      setTutores(Array.isArray(lista) ? lista : []);
      if (res.pagination) {
        setTotal(res.pagination.total || lista.length);
        setTotalPaginas(res.pagination.pages || 1);
      } else {
        setTotal(lista.length);
        setTotalPaginas(1);
      }
    } catch (e) {
      console.error('Error cargando tutores', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const t = setTimeout(cargarTutores, 300);
    return () => clearTimeout(t);
  }, [busqueda, pagina, filtroFacturantes]);

  const abrirCrear = () => {
    setTutorActual(TUTOR_INIT);
    setError('');
    setModal('crear');
  };

  const abrirEditar = (t: Tutor) => {
    setTutorActual({ ...t });
    setError('');
    setModal('editar');
  };

  const abrirVer = (t: Tutor) => {
    navigate(`/tutores/${t.tutorId || t.id}`);
  };

  const cerrarModal = () => {
    setModal(null);
    setTutorActual(TUTOR_INIT);
    setError('');
  };

  const guardar = async () => {
    if (!tutorActual.nombreCompleto?.trim()) {
      setError('El nombre es obligatorio.');
      return;
    }
    setGuardando(true);
    setError('');
    try {
      if (modal === 'crear') {
        await api.post('/tutores', tutorActual);
      } else if (modal === 'editar') {
        const id = tutorActual.tutorId || tutorActual.id;
        await api.put(`/tutores/${id}`, tutorActual);
      }
      cerrarModal();
      cargarTutores();
    } catch (e: any) {
      setError(e?.response?.data?.message || 'Error al guardar');
    } finally {
      setGuardando(false);
    }
  };

  const toggleActivo = async (tutor: Tutor) => {
    const id = tutor.tutorId || tutor.id;
    if (!confirm(`¿${tutor.activo ? 'Desactivar' : 'Activar'} a ${tutor.nombreCompleto}?`)) return;
    try {
      await api.put(`/tutores/${id}`, { activo: !tutor.activo });
      cargarTutores();
    } catch (e: any) {
      alert(e?.response?.data?.message || 'Error al cambiar estado');
    }
  };

  return (
    <div className="h-full flex flex-col">
      {/* Header */}
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-navy-800">Padres & Tutores</h2>
          <p className="text-gray-500 text-sm mt-1">{total} tutor(es) registrados</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => { setFiltroFacturantes(f => !f); setPagina(1); }}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl border font-medium text-sm transition-colors ${
              filtroFacturantes 
                ? 'bg-amber-500 text-white border-amber-500 shadow-sm' 
                : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
            }`}
          >
            <FileText size={16} />
            {filtroFacturantes ? 'Ver Todos' : 'Solo Facturantes'}
          </button>
          <button
            onClick={exportarFacturantes}
            className="flex items-center gap-2 px-4 py-2 rounded-xl border border-gray-200 bg-white text-gray-600 hover:bg-gray-50 font-medium text-sm transition-colors"
          >
            <Download size={16} /> Exportar CSV
          </button>
          <button
            onClick={abrirCrear}
            className="flex items-center gap-2 px-4 py-2 bg-navy-800 text-white rounded-xl hover:bg-navy-900 shadow-sm font-medium text-sm transition-colors"
          >
            <Plus size={16} />
            Nuevo Tutor
          </button>
        </div>
      </div>

      {/* Search */}
      <div className="relative mb-4">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          placeholder="Buscar por nombre, RFC, correo..."
          className="w-full pl-9 pr-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none text-sm bg-white"
          value={busqueda}
          onChange={e => { setBusqueda(e.target.value); setPagina(1); }}
        />
        {busqueda && (
          <button onClick={() => setBusqueda('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
            <X size={14} />
          </button>
        )}
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 flex-1 overflow-hidden flex flex-col">
        <div className="overflow-x-auto flex-1">
          <table className="w-full text-sm text-left">
            <thead className="bg-gray-50 border-b border-gray-100 text-gray-600">
              <tr>
                <th className="px-6 py-4 font-semibold">Tutor / Contacto</th>
                <th className="px-6 py-4 font-semibold">RFC</th>
                <th className="px-6 py-4 font-semibold">Factura</th>
                <th className="px-6 py-4 font-semibold">Alumnos</th>
                <th className="px-6 py-4 font-semibold">Estado</th>
                <th className="px-6 py-4 font-semibold text-right">Acciones</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={5} className="px-6 py-16 text-center text-gray-400">
                  <div className="flex flex-col items-center gap-2">
                    <div className="w-8 h-8 border-2 border-navy-500 border-t-transparent rounded-full animate-spin" />
                    Cargando tutores...
                  </div>
                </td></tr>
              ) : tutores.length === 0 ? (
                <tr><td colSpan={5} className="px-6 py-16 text-center text-gray-400">
                  <User size={40} className="mx-auto mb-2 opacity-30" />
                  No se encontraron tutores.
                </td></tr>
              ) : tutores.map(tutor => (
                <tr key={tutor.tutorId || tutor.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                  <td className="px-6 py-4">
                    <div className="font-medium text-gray-900">{tutor.nombreCompleto || 'Sin nombre'}</div>
                    <div className="text-xs text-gray-500 flex items-center gap-3 mt-0.5">
                      {tutor.correoElectronico && <span className="flex items-center gap-1"><Mail size={11} />{tutor.correoElectronico}</span>}
                      {tutor.telefono && <span className="flex items-center gap-1"><Phone size={11} />{tutor.telefono}</span>}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-gray-600 font-mono text-xs">{tutor.rfc || '—'}</td>
                  <td className="px-6 py-4">
                    {tutor.requiereFactura ? (
                      <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-amber-50 text-amber-700 border border-amber-200">
                        <FileText size={10} /> Factura
                      </span>
                    ) : (
                      <span className="text-gray-400 text-xs">—</span>
                    )}
                  </td>
                  <td className="px-6 py-4">
                    <span className="text-xs text-gray-500">
                      {tutor.alumnos && tutor.alumnos.length > 0 ? `${tutor.alumnos.length} vinculado(s)` : 'Ninguno'}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${tutor.activo !== false ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                      {tutor.activo !== false ? 'Activo' : 'Inactivo'}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <button
                        onClick={() => abrirVer(tutor)}
                        className="px-3 py-1.5 text-xs bg-blue-50 text-blue-700 rounded-lg hover:bg-blue-100 transition-colors"
                      >
                        Ver
                      </button>
                      <button
                        onClick={() => abrirEditar(tutor)}
                        className="p-1.5 text-gray-400 hover:text-navy-700 hover:bg-gray-100 rounded-lg transition-colors"
                      >
                        <Edit2 size={14} />
                      </button>
                      <button
                        onClick={() => toggleActivo(tutor)}
                        className={`p-1.5 rounded-lg transition-colors ${tutor.activo !== false ? 'text-gray-400 hover:text-red-600 hover:bg-red-50' : 'text-gray-400 hover:text-green-600 hover:bg-green-50'}`}
                        title={tutor.activo !== false ? 'Desactivar' : 'Activar'}
                      >
                        {tutor.activo !== false ? <XCircle size={14} /> : <CheckCircle size={14} />}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPaginas > 1 && (
          <div className="border-t border-gray-100 px-6 py-3 flex items-center justify-between bg-gray-50/50">
            <span className="text-xs text-gray-500">Página {pagina} de {totalPaginas}</span>
            <div className="flex gap-2">
              <button
                disabled={pagina <= 1}
                onClick={() => setPagina(p => p - 1)}
                className="p-1.5 rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed"
              ><ChevronLeft size={14} /></button>
              <button
                disabled={pagina >= totalPaginas}
                onClick={() => setPagina(p => p + 1)}
                className="p-1.5 rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed"
              ><ChevronRight size={14} /></button>
            </div>
          </div>
        )}
      </div>

      {/* Modal Crear / Editar */}
      {(modal === 'crear' || modal === 'editar') && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" onClick={cerrarModal}>
          <div className="bg-white rounded-2xl p-6 w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
            <div className="flex justify-between items-center mb-5">
              <h3 className="font-bold text-lg text-navy-800">{modal === 'crear' ? 'Registrar Nuevo Tutor' : 'Editar Tutor'}</h3>
              <button onClick={cerrarModal} className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500"><X size={16} /></button>
            </div>

            {error && <div className="mb-4 px-4 py-3 rounded-xl bg-red-50 text-red-700 text-sm border border-red-200">{error}</div>}

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nombre Completo <span className="text-red-500">*</span></label>
                <input type="text" className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={tutorActual.nombreCompleto || ''}
                  onChange={e => setTutorActual({ ...tutorActual, nombreCompleto: e.target.value })} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Teléfono</label>
                  <input type="text" className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                    value={tutorActual.telefono || ''}
                    onChange={e => setTutorActual({ ...tutorActual, telefono: e.target.value })} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Correo Electrónico</label>
                  <input type="email" className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                    value={tutorActual.correoElectronico || ''}
                    onChange={e => setTutorActual({ ...tutorActual, correoElectronico: e.target.value })} />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">RFC</label>
                  <input type="text" className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none uppercase"
                    value={tutorActual.rfc || ''}
                    onChange={e => setTutorActual({ ...tutorActual, rfc: e.target.value.toUpperCase() })} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">CURP</label>
                  <input type="text" className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none uppercase"
                    value={tutorActual.curp || ''}
                    onChange={e => setTutorActual({ ...tutorActual, curp: e.target.value.toUpperCase() })} />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Dirección</label>
                <input type="text" className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={tutorActual.direccion || ''}
                  onChange={e => setTutorActual({ ...tutorActual, direccion: e.target.value })} />
              </div>
              <div className="flex items-center gap-3 pt-1">
                <input type="checkbox" id="requiereFactura" className="w-4 h-4 accent-navy-700"
                  checked={!!tutorActual.requiereFactura}
                  onChange={e => setTutorActual({ ...tutorActual, requiereFactura: e.target.checked })} />
                <label htmlFor="requiereFactura" className="text-sm font-medium text-gray-700">Requiere Factura</label>
              </div>

              {tutorActual.requiereFactura && (
                <div className="grid grid-cols-2 gap-4 border-t pt-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Régimen Fiscal</label>
                    <input type="text" className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                      value={tutorActual.regimenFiscal || ''}
                      onChange={e => setTutorActual({ ...tutorActual, regimenFiscal: e.target.value })} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Uso CFDI</label>
                    <input type="text" placeholder="Ej. D10, G01..." className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none uppercase"
                      value={tutorActual.usoCfdi || ''}
                      onChange={e => setTutorActual({ ...tutorActual, usoCfdi: e.target.value.toUpperCase() })} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Correo Facturación</label>
                    <input type="email" className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                      value={tutorActual.correoFacturacion || ''}
                      onChange={e => setTutorActual({ ...tutorActual, correoFacturacion: e.target.value })} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Código Postal</label>
                    <input type="text" className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                      value={tutorActual.codigoPostal || ''}
                      onChange={e => setTutorActual({ ...tutorActual, codigoPostal: e.target.value })} />
                  </div>
                  <div className="col-span-2">
                    <label className="block text-sm font-medium text-gray-700 mb-1">Dirección Fiscal</label>
                    <input type="text" className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                      value={tutorActual.direccionFiscal || ''}
                      onChange={e => setTutorActual({ ...tutorActual, direccionFiscal: e.target.value })} />
                  </div>
                </div>
              )}
            </div>

            <div className="mt-6 flex justify-end gap-3">
              <button onClick={cerrarModal} className="px-4 py-2 border border-gray-200 rounded-xl text-gray-600 hover:bg-gray-50 text-sm">Cancelar</button>
              <button onClick={guardar} disabled={guardando}
                className="px-6 py-2 bg-navy-800 text-white rounded-xl hover:bg-navy-900 shadow-sm font-medium text-sm disabled:opacity-50">
                {guardando ? 'Guardando...' : modal === 'crear' ? 'Registrar Tutor' : 'Guardar Cambios'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Ver Modal removido a favor de TutorPerfil */}
    </div>
  );
}
