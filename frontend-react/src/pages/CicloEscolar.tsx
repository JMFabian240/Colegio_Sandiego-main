import React, { useState, useEffect } from 'react';
import { Settings, Plus, Save, AlertTriangle, Lock, X } from 'lucide-react';
import { tarifasService } from '../services/tarifas.service';
import { alumnosService } from '../services/alumnos.service';

export function CicloEscolar() {
  const [ciclos, setCiclos] = useState<any[]>([]);
  const [niveles, setNiveles] = useState<any[]>([]);
  
  const [cicloId, setCicloId] = useState('');
  const [nivelId, setNivelId] = useState('');
  const [cicloActivo, setCicloActivo] = useState(false);
  const [loadingTarifas, setLoadingTarifas] = useState(false);
  const [saving, setSaving] = useState(false);

  const [conceptos, setConceptos] = useState({
    colegiatura: '',
    inscripcion: '',
    arancel: '',
    material: ''
  });

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [nuevoCiclo, setNuevoCiclo] = useState({ nombre: '', activo: true });
  const [isClosing, setIsClosing] = useState(false);

  useEffect(() => {
    cargarCiclosYNiveles();
  }, []);

  const cargarCiclosYNiveles = async () => {
    try {
      const resC: any = await tarifasService.obtenerCiclos();
      setCiclos(resC.data?.data || resC.data || []);
      
      const resN: any = await tarifasService.obtenerNiveles();
      setNiveles(resN.data?.data || resN.data || []);
    } catch (error) {
      console.error('Error cargando catálogos', error);
    }
  };

  useEffect(() => {
    if (cicloId) {
      const c = ciclos.find(x => x.cicloId === Number(cicloId) || x.cicloId === cicloId);
      setCicloActivo(c?.activo || false);
    }
    
    if (cicloId && nivelId) {
      cargarTarifas();
    } else {
      setConceptos({ colegiatura: '', inscripcion: '', arancel: '', material: '' });
    }
  }, [cicloId, nivelId]);

  const cargarTarifas = async () => {
    setLoadingTarifas(true);
    try {
      const res: any = await tarifasService.obtenerTarifas(Number(cicloId), Number(nivelId));
      const data = res.data?.data || res.data || [];
      const nuevosConceptos = { colegiatura: '', inscripcion: '', arancel: '', material: '' };
      data.forEach((t: any) => {
        if (t.concepto === 'colegiatura') nuevosConceptos.colegiatura = String(Number(t.monto) * 10);
        if (t.concepto === 'inscripcion') nuevosConceptos.inscripcion = t.monto;
        if (t.concepto === 'arancel') nuevosConceptos.arancel = t.monto;
        if (t.concepto === 'material') nuevosConceptos.material = t.monto;
      });
      setConceptos(nuevosConceptos);
    } catch (error) {
      console.error('Error cargando tarifas', error);
    } finally {
      setLoadingTarifas(false);
    }
  };

  const handleGuardarTarifas = async () => {
    if (!window.confirm("¿Está seguro que desea guardar esta configuración de montos para el ciclo escolar seleccionado?")) return;
    
    const tarifasArray = [];
    for (const [key, val] of Object.entries(conceptos)) {
      if (!val || Number(val) <= 0) {
        alert(`El monto para ${key} es inválido. Debe ser mayor a 0.`);
        return;
      }
      let monto = Number(val);
      if (key === 'colegiatura') monto = monto / 10;
      tarifasArray.push({ concepto: key, monto });
    }

    setSaving(true);
    try {
      await tarifasService.guardarTarifas({
        cicloId: Number(cicloId),
        nivelId: Number(nivelId),
        tarifas: tarifasArray
      });
      alert('Configuración guardada correctamente.');
      cargarTarifas();
    } catch (error) {
      console.error('Error guardando tarifas', error);
      alert('Error al guardar las tarifas.');
    } finally {
      setSaving(false);
    }
  };

  const handleCrearCiclo = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!nuevoCiclo.nombre) return;
    setSaving(true);
    try {
      await tarifasService.crearCiclo(nuevoCiclo);
      alert('Ciclo creado exitosamente.');
      setIsModalOpen(false);
      setNuevoCiclo({ nombre: '', activo: true });
      cargarCiclosYNiveles();
    } catch (error) {
      console.error('Error creando ciclo', error);
      alert('Error al crear el ciclo escolar.');
    } finally {
      setSaving(false);
    }
  };

  const handleReactivarCiclo = async () => {
    if (!window.confirm("¿Estás seguro de reactivar este ciclo? El ciclo actual pasará a ser histórico.")) return;
    setSaving(true);
    try {
      await tarifasService.activarCiclo(Number(cicloId));
      alert('Ciclo reactivado correctamente.');
      cargarCiclosYNiveles();
    } catch (error) {
      console.error('Error reactivando ciclo', error);
      alert('Error al reactivar el ciclo.');
    } finally {
      setSaving(false);
    }
  };

  const handleCierreCiclo = async () => {
    if (confirm('¿Estás SEGURO de querer cerrar el ciclo? Esta acción es irreversible, promoverá a los alumnos y cerrará el ciclo actual.')) {
      setIsClosing(true);
      try {
        const res = await alumnosService.cerrarCiclo();
        alert(`¡Ciclo cerrado con éxito!\n\nPromovidos: ${res.data.data.promovidos}\nEgresados: ${res.data.data.egresados}\nRetenidos: ${res.data.data.retenidos}`);
        cargarCiclosYNiveles();
      } catch (error: any) {
        console.error(error);
        alert(error.response?.data?.message || 'Ocurrió un error al cerrar el ciclo.');
      } finally {
        setIsClosing(false);
      }
    }
  };

  return (
    <div className="h-full flex flex-col relative overflow-hidden">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-navy-800">Configuración del Ciclo Escolar</h2>
          <p className="text-sm text-gray-500 mt-1">Gestiona ciclos, tarifas por nivel y procesos de cierre.</p>
        </div>
        <button 
          className="flex items-center gap-2 px-4 py-2 bg-navy-600 text-white rounded-xl hover:bg-navy-700 transition-colors shadow-sm font-medium"
          onClick={() => setIsModalOpen(true)}
        >
          <Plus size={16} /> Nuevo Ciclo
        </button>
      </div>

      <div className="flex-1 overflow-auto">
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-6">
          <div className="grid md:grid-cols-2 gap-8">
            <div className="space-y-4">
              <div>
                <label className="text-sm font-medium text-gray-700 block mb-1">Seleccionar Ciclo Escolar</label>
                <select 
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={cicloId}
                  onChange={(e) => setCicloId(e.target.value)}
                >
                  <option value="" disabled>Seleccione un ciclo</option>
                  {ciclos.map(c => (
                    <option key={c.cicloId} value={c.cicloId}>
                      {c.nombre} {c.activo ? '(Activo)' : '(Histórico)'}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-sm font-medium text-gray-700 block mb-1">Seleccionar Nivel Educativo</label>
                <select 
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={nivelId}
                  onChange={(e) => setNivelId(e.target.value)}
                >
                  <option value="" disabled>Seleccione un nivel</option>
                  {niveles.map(n => (
                    <option key={n.nivelId} value={n.nivelId}>{n.nombre}</option>
                  ))}
                </select>
              </div>
            </div>

            <div className="h-full flex flex-col justify-center">
              {cicloId && !cicloActivo ? (
                <div className="bg-amber-50 p-5 rounded-2xl border border-amber-100 flex flex-col gap-4">
                  <div className="flex gap-4">
                    <div className="text-amber-500 mt-0.5"><Lock size={20} /></div>
                    <div>
                      <div className="font-bold text-amber-800 mb-1">Ciclo Escolar Cerrado</div>
                      <p className="text-sm text-amber-700/80">
                        Este ciclo escolar ya no está activo. Las tarifas son de solo lectura y no pueden modificarse para preservar la integridad de los registros históricos.
                      </p>
                    </div>
                  </div>
                  <div className="flex justify-end border-t border-amber-200 pt-3">
                    <button 
                      className="px-4 py-1.5 bg-amber-600 text-white text-sm rounded-lg hover:bg-amber-700 font-medium transition-colors"
                      onClick={handleReactivarCiclo}
                      disabled={saving}
                    >
                      {saving ? 'Reactivando...' : 'Reactivar este ciclo'}
                    </button>
                  </div>
                </div>
              ) : (
                <div className="bg-navy-50/50 p-5 rounded-2xl border border-navy-50 flex items-center justify-center text-center h-full">
                  <div className="text-navy-600/70">
                    <Settings className="w-8 h-8 mx-auto mb-2 opacity-50" />
                    <p className="text-sm font-medium">Selecciona un nivel y un ciclo activo para configurar sus tarifas.</p>
                  </div>
                </div>
              )}
            </div>
          </div>

          {cicloId && nivelId && (
            <div className={`mt-8 pt-6 border-t border-gray-100 ${loadingTarifas ? 'opacity-50 pointer-events-none' : ''}`}>
              <h3 className="font-bold text-gray-800 mb-4 flex items-center gap-2">
                <Settings size={18} className="text-navy-600" /> Montos Configurables
              </h3>
              
              <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">Colegiatura Anual</label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
                    <input 
                      type="number" 
                      className="w-full pl-8 pr-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none disabled:bg-gray-50"
                      value={conceptos.colegiatura}
                      onChange={(e) => setConceptos({...conceptos, colegiatura: e.target.value})}
                      disabled={!cicloActivo || saving}
                    />
                  </div>
                  {Number(conceptos.colegiatura) > 0 && (
                    <div className="mt-3 text-xs text-gray-500 bg-gray-50 p-3 rounded-xl border border-gray-100">
                      <div className="flex justify-between mb-1.5">
                        <span>A 10 meses:</span> 
                        <span className="font-semibold text-gray-700">${(Number(conceptos.colegiatura) / 10).toLocaleString('es-MX', {minimumFractionDigits: 2})}</span>
                      </div>
                      <div className="flex justify-between">
                        <span>A 12 meses:</span> 
                        <span className="font-semibold text-gray-700">${(Number(conceptos.colegiatura) / 12).toLocaleString('es-MX', {minimumFractionDigits: 2})}</span>
                      </div>
                    </div>
                  )}
                </div>

                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">Inscripción Anual</label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
                    <input 
                      type="number" 
                      className="w-full pl-8 pr-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none disabled:bg-gray-50"
                      value={conceptos.inscripcion}
                      onChange={(e) => setConceptos({...conceptos, inscripcion: e.target.value})}
                      disabled={!cicloActivo || saving}
                    />
                  </div>
                </div>

                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">Aranceles</label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
                    <input 
                      type="number" 
                      className="w-full pl-8 pr-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none disabled:bg-gray-50"
                      value={conceptos.arancel}
                      onChange={(e) => setConceptos({...conceptos, arancel: e.target.value})}
                      disabled={!cicloActivo || saving}
                    />
                  </div>
                </div>

                <div>
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">Materiales</label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
                    <input 
                      type="number" 
                      className="w-full pl-8 pr-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none disabled:bg-gray-50"
                      value={conceptos.material}
                      onChange={(e) => setConceptos({...conceptos, material: e.target.value})}
                      disabled={!cicloActivo || saving}
                    />
                  </div>
                </div>
              </div>

              {cicloActivo && (
                <div className="flex justify-end mt-6">
                  <button 
                    onClick={handleGuardarTarifas}
                    disabled={saving}
                    className="flex items-center gap-2 px-6 py-2.5 bg-navy-600 text-white rounded-xl hover:bg-navy-700 transition-colors shadow-sm font-medium disabled:opacity-70"
                  >
                    <Save size={18} /> {saving ? 'Guardando...' : 'Guardar Configuración'}
                  </button>
                </div>
              )}
            </div>
          )}
        </div>

        <div className="bg-red-50/50 rounded-2xl border border-red-100 p-6">
          <div className="flex gap-4">
            <div className="text-red-500 mt-1"><AlertTriangle size={24} /></div>
            <div>
              <h3 className="text-lg font-bold text-red-700 mb-1">Zona Crítica: Cierre de Ciclo Escolar</h3>
              <p className="text-sm text-red-700/80 mb-4 max-w-3xl">
                Al ejecutar el cierre de ciclo escolar, se promoverá masivamente a todos los alumnos regulares al siguiente grado y se retendrá a aquellos con adeudos significativos. El ciclo actual se marcará como cerrado irreversiblemente y no podrá recibir más modificaciones de tarifas ni inscripciones.
              </p>
              <button 
                onClick={handleCierreCiclo}
                disabled={isClosing}
                className="px-5 py-2.5 bg-white border border-red-200 text-red-600 font-bold rounded-xl hover:bg-red-50 transition-colors shadow-sm disabled:opacity-50"
              >
                {isClosing ? 'Cerrando Ciclo...' : 'Ejecutar Cierre de Ciclo'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Modal Nuevo Ciclo */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl w-full max-w-md shadow-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h3 className="text-lg font-bold text-navy-800">Crear Nuevo Ciclo</h3>
              <button onClick={() => setIsModalOpen(false)} className="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-gray-100 transition-colors">
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleCrearCiclo} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nombre del Ciclo</label>
                <input 
                  type="text" 
                  required
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={nuevoCiclo.nombre}
                  onChange={(e) => setNuevoCiclo({...nuevoCiclo, nombre: e.target.value})}
                  placeholder="Ej. 2026-2027"
                />
              </div>

              <div>
                <label className="flex items-center gap-3 p-4 border border-gray-200 rounded-xl cursor-pointer hover:bg-gray-50 transition-colors">
                  <input 
                    type="checkbox" 
                    className="w-5 h-5 rounded border-gray-300 text-navy-600 focus:ring-navy-600"
                    checked={nuevoCiclo.activo}
                    onChange={(e) => setNuevoCiclo({...nuevoCiclo, activo: e.target.checked})}
                  />
                  <div>
                    <div className="font-semibold text-gray-800">Marcar como Activo</div>
                    <div className="text-xs text-gray-500">Este será el ciclo actual donde se inscribirán los alumnos.</div>
                  </div>
                </label>
              </div>

              <div className="pt-4 flex justify-end gap-3">
                <button 
                  type="button" 
                  onClick={() => setIsModalOpen(false)}
                  className="px-5 py-2.5 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors"
                >
                  Cancelar
                </button>
                <button 
                  type="submit"
                  disabled={saving}
                  className="px-5 py-2.5 text-sm font-medium text-white bg-navy-600 hover:bg-navy-700 rounded-xl transition-colors shadow-sm disabled:opacity-70"
                >
                  {saving ? 'Guardando...' : 'Crear Ciclo'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
