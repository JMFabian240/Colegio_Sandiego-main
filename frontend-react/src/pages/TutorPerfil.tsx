import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft, User, Phone, Mail, FileText, CreditCard, Clock, Receipt } from 'lucide-react';
import api from '../services/api';
import type { Tutor } from '../types';

export function TutorPerfil() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [tutor, setTutor] = useState<Tutor | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchTutor = async () => {
      try {
        const res: any = await api.get(`/tutores/${id}`);
        setTutor(res.data || res);
      } catch (err) {
        console.error('Error cargando tutor:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchTutor();
  }, [id]);

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-navy-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!tutor) {
    return (
      <div className="h-full flex flex-col items-center justify-center text-gray-500">
        <User size={48} className="opacity-20 mb-4" />
        <p>No se encontró el tutor.</p>
        <button onClick={() => navigate('/tutores')} className="mt-4 text-navy-600 hover:underline">Volver</button>
      </div>
    );
  }

  // Format currency
  const formatMoney = (amount: number) => {
    return new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(amount);
  };

  // Format date
  const formatDate = (dateString: string) => {
    if (!dateString) return '—';
    return new Date(dateString).toLocaleDateString('es-MX', { year: 'numeric', month: 'short', day: 'numeric' });
  };

  return (
    <div className="h-full flex flex-col overflow-y-auto pr-2 pb-8">
      {/* Header */}
      <div className="flex items-center gap-4 mb-6">
        <button onClick={() => navigate('/tutores')} className="p-2 rounded-xl border border-gray-200 hover:bg-gray-50 text-gray-500 transition-colors">
          <ArrowLeft size={18} />
        </button>
        <div className="flex-1">
          <h2 className="text-2xl font-bold text-navy-800">{tutor.nombreCompleto}</h2>
          <div className="flex items-center gap-3 text-sm text-gray-500 mt-1">
            <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${tutor.activo !== false ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
              {tutor.activo !== false ? 'Cuenta Activa' : 'Cuenta Inactiva'}
            </span>
            <span>ID: {tutor.tutorId || tutor.id}</span>
          </div>
        </div>
        <div className="text-right bg-white p-3 rounded-xl border border-gray-100 shadow-sm">
          <p className="text-xs text-gray-500 font-medium uppercase tracking-wider mb-1">Saldo a Favor</p>
          <p className={`text-xl font-bold ${Number(tutor.saldoAFavor) > 0 ? 'text-green-600' : 'text-gray-900'}`}>
            {formatMoney(Number(tutor.saldoAFavor) || 0)}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column */}
        <div className="lg:col-span-1 space-y-6">
          {/* Info Card */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
            <h3 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <User size={16} className="text-navy-500" /> Información General
            </h3>
            <div className="space-y-4 text-sm">
              <div>
                <p className="text-gray-500 text-xs mb-1">Teléfono</p>
                <div className="flex items-center gap-2 text-gray-900 font-medium">
                  <Phone size={14} className="text-gray-400" /> {tutor.telefono || '—'}
                </div>
              </div>
              <div>
                <p className="text-gray-500 text-xs mb-1">Correo Electrónico</p>
                <div className="flex items-center gap-2 text-gray-900 font-medium break-all">
                  <Mail size={14} className="text-gray-400" /> {tutor.correoElectronico || '—'}
                </div>
              </div>
              <div className="pt-3 border-t border-gray-50">
                <p className="text-gray-500 text-xs mb-1">Dirección</p>
                <p className="text-gray-900">{tutor.direccion || 'No registrada'}</p>
              </div>
              <div className="grid grid-cols-2 gap-4 pt-3 border-t border-gray-50">
                <div>
                  <p className="text-gray-500 text-xs mb-1">RFC</p>
                  <p className="font-mono text-gray-900">{tutor.rfc || '—'}</p>
                </div>
                <div>
                  <p className="text-gray-500 text-xs mb-1">CURP</p>
                  <p className="font-mono text-gray-900">{tutor.curp || '—'}</p>
                </div>
              </div>
            </div>
          </div>

          {/* Facturacion Card */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-gray-900 flex items-center gap-2">
                <FileText size={16} className="text-navy-500" /> Datos de Facturación
              </h3>
              {tutor.requiereFactura ? (
                <span className="px-2 py-1 bg-blue-50 text-blue-700 text-xs rounded-lg font-medium">Requiere Factura</span>
              ) : (
                <span className="px-2 py-1 bg-gray-100 text-gray-500 text-xs rounded-lg font-medium">No requiere</span>
              )}
            </div>
            
            {tutor.requiereFactura && (
              <div className="space-y-4 text-sm">
                <div>
                  <p className="text-gray-500 text-xs mb-1">Régimen Fiscal</p>
                  <p className="text-gray-900 font-medium">{tutor.regimenFiscal || '—'}</p>
                  {!tutor.regimenFiscal && <p className="text-xs text-red-500 mt-1">Falta dato obligatorio</p>}
                </div>
                <div>
                  <p className="text-gray-500 text-xs mb-1">Correo de Facturación</p>
                  <p className="text-gray-900">{tutor.correoFacturacion || tutor.correoElectronico || '—'}</p>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Right Column */}
        <div className="lg:col-span-2 space-y-6">
          {/* Alumnos Vinculados */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <div className="px-5 py-4 border-b border-gray-100">
              <h3 className="font-semibold text-gray-900">Alumnos Vinculados</h3>
            </div>
            {tutor.alumnos && tutor.alumnos.length > 0 ? (
              <div className="divide-y divide-gray-50">
                {tutor.alumnos.map((rel: any, idx: number) => {
                  const alumno = rel.alumno || rel; // Depending on how populate works
                  return (
                    <div key={idx} className="p-5 flex items-center justify-between hover:bg-gray-50 transition-colors">
                      <div className="flex items-center gap-4">
                        <div className="w-10 h-10 rounded-full bg-navy-50 flex items-center justify-center text-navy-600 font-bold">
                          {alumno.nombreCompleto?.charAt(0) || 'A'}
                        </div>
                        <div>
                          <p className="font-semibold text-gray-900">{alumno.nombreCompleto}</p>
                          <div className="flex items-center gap-2 mt-1">
                            <span className="text-xs text-gray-500 font-mono">Matrícula: {alumno.matricula || '—'}</span>
                            <span className="w-1 h-1 bg-gray-300 rounded-full"></span>
                            <span className="text-xs text-gray-500">{alumno.nivel?.nombre || 'Sin nivel'}</span>
                          </div>
                        </div>
                      </div>
                      <button onClick={() => navigate(`/alumnos?id=${alumno.alumnoId}`)} className="text-navy-600 hover:text-navy-800 text-sm font-medium px-3 py-1.5 rounded-lg hover:bg-navy-50 transition-colors">
                        Ver Expediente
                      </button>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="p-8 text-center text-gray-500 text-sm">
                No hay alumnos vinculados a este tutor.
              </div>
            )}
          </div>

          {/* Historial de Pagos y Movimientos */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
              <h3 className="font-semibold text-gray-900 flex items-center gap-2">
                <CreditCard size={16} className="text-navy-500" /> Últimos Pagos
              </h3>
            </div>
            {tutor.pagos && tutor.pagos.length > 0 ? (
              <table className="w-full text-sm text-left">
                <thead className="bg-gray-50 text-gray-500 text-xs uppercase tracking-wider">
                  <tr>
                    <th className="px-5 py-3 font-medium">Fecha</th>
                    <th className="px-5 py-3 font-medium">Método</th>
                    <th className="px-5 py-3 font-medium text-right">Monto</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {tutor.pagos.map((pago: any, idx: number) => (
                    <tr key={idx} className="hover:bg-gray-50">
                      <td className="px-5 py-3 text-gray-900">{formatDate(pago.fechaPago)}</td>
                      <td className="px-5 py-3 text-gray-600 capitalize">{pago.metodoPago}</td>
                      <td className="px-5 py-3 text-right font-medium text-gray-900">{formatMoney(Number(pago.montoTotal))}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <div className="p-8 text-center text-gray-500 text-sm flex flex-col items-center">
                <Clock size={32} className="opacity-20 mb-2" />
                No hay pagos recientes registrados.
              </div>
            )}
          </div>

          {/* Facturas */}
          {tutor.requiereFactura && (
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="px-5 py-4 border-b border-gray-100">
                <h3 className="font-semibold text-gray-900 flex items-center gap-2">
                  <Receipt size={16} className="text-navy-500" /> Facturas Emitidas
                </h3>
              </div>
              {tutor.facturas && tutor.facturas.length > 0 ? (
                <table className="w-full text-sm text-left">
                  <thead className="bg-gray-50 text-gray-500 text-xs uppercase tracking-wider">
                    <tr>
                      <th className="px-5 py-3 font-medium">Folio/UUID</th>
                      <th className="px-5 py-3 font-medium">Fecha</th>
                      <th className="px-5 py-3 font-medium">Estado</th>
                      <th className="px-5 py-3 font-medium text-right">Monto</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {tutor.facturas.map((fac: any, idx: number) => (
                      <tr key={idx} className="hover:bg-gray-50">
                        <td className="px-5 py-3">
                          <p className="font-medium text-gray-900">{fac.numeroFactura || 'Sin Folio'}</p>
                          {fac.uuidSat && <p className="text-xs text-gray-500 font-mono truncate max-w-[150px]" title={fac.uuidSat}>{fac.uuidSat}</p>}
                        </td>
                        <td className="px-5 py-3 text-gray-600">{formatDate(fac.fechaEmision)}</td>
                        <td className="px-5 py-3">
                          <span className={`px-2 py-1 rounded-md text-xs font-medium ${fac.estado === 'emitida' ? 'bg-green-50 text-green-700' : 'bg-gray-100 text-gray-600'}`}>
                            {fac.estado}
                          </span>
                        </td>
                        <td className="px-5 py-3 text-right font-medium text-gray-900">{formatMoney(Number(fac.montoTotal))}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <div className="p-8 text-center text-gray-500 text-sm">
                  Aún no se han emitido facturas para este tutor.
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
