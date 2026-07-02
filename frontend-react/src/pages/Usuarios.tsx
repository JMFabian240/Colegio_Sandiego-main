import React, { useState, useEffect } from 'react';
import { Users, Shield, Key, Search, UserPlus, Trash2, Edit, Save, X, RefreshCcw, Plus, UserCircle, Eye, EyeOff } from 'lucide-react';
import { usuariosService } from '../services/usuarios.service';

export function Usuarios() {
  const [usuarios, setUsuarios] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState('');
  const [filtroRol, setFiltroRol] = useState('');
  const [mostrarInactivos, setMostrarInactivos] = useState(false);

  // Modal Nuevo Usuario
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [nuevoUsuario, setNuevoUsuario] = useState({
    nombre: '',
    username: '',
    password: '',
    rol: 'MAESTRA'
  });

  const [selectedUser, setSelectedUser] = useState<any>(null);
  
  // Permissions state
  const [modulosValidos, setModulosValidos] = useState<string[]>([]);
  const [permisosActivos, setPermisosActivos] = useState<Record<string, 'NINGUNO' | 'lectura' | 'escritura'>>({});
  const [loadingPermisos, setLoadingPermisos] = useState(false);

  const cargarUsuarios = async () => {
    setLoading(true);
    try {
      const res: any = await usuariosService.obtenerTodos({ includeInactivos: true });
      const data = res.data?.data || res.data || [];
      setUsuarios(data);
    } catch (error) {
      console.error('Error cargando usuarios', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    cargarUsuarios();
  }, [mostrarInactivos]);

  useEffect(() => {
    if (selectedUser) {
      cargarPermisosUsuario(selectedUser.id || selectedUser.usuarioId);
    }
  }, [selectedUser]);

  const cargarPermisosUsuario = async (userId: number) => {
    setLoadingPermisos(true);
    try {
      let modulos = modulosValidos;
      if (modulos.length === 0) {
        const resModulos: any = await usuariosService.obtenerModulos();
        modulos = resModulos.data || resModulos || [];
        setModulosValidos(modulos);
      }

      const resPermisos: any = await usuariosService.obtenerPermisosUsuario(userId);
      const asignados = resPermisos.data || resPermisos || [];
      
      const newPermisosMap: Record<string, 'NINGUNO' | 'lectura' | 'escritura'> = {};
      
      modulos.forEach((mod: string) => {
        newPermisosMap[mod] = 'NINGUNO';
      });

      asignados.forEach((p: any) => {
        if (newPermisosMap[p.modulo] !== undefined) {
          newPermisosMap[p.modulo] = p.nivel;
        }
      });

      setPermisosActivos(newPermisosMap);

    } catch (error) {
      console.error('Error cargando permisos', error);
    } finally {
      setLoadingPermisos(false);
    }
  };

  const handleCrearUsuario = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await usuariosService.crear(nuevoUsuario);
      alert('Usuario creado exitosamente');
      setIsModalOpen(false);
      setNuevoUsuario({ nombre: '', username: '', password: '', rol: 'MAESTRA' });
      cargarUsuarios();
    } catch (error) {
      console.error('Error creando usuario', error);
      alert('Error al crear usuario. Verifica que el nombre de usuario no exista ya.');
    }
  };

  const handleToggleEstado = async (user: any) => {
    try {
      if (user.estado === 'inactivo') {
        await usuariosService.reactivar(user.id || user.usuarioId);
        alert('Usuario reactivado exitosamente.');
      } else {
        if (!window.confirm(`¿Estás seguro de desactivar a ${user.nombre}?`)) return;
        await usuariosService.eliminar(user.id || user.usuarioId);
        alert('Usuario desactivado exitosamente.');
      }
      cargarUsuarios();
      setSelectedUser(null);
    } catch (error) {
      console.error('Error cambiando estado', error);
      alert('Error al cambiar el estado del usuario');
    }
  };

  const handleRestablecerPassword = async (user: any) => {
    const newPassword = window.prompt(`Ingresa la nueva contraseña para el usuario ${user.nombre}:`);
    if (!newPassword) return;
    
    if (newPassword.length < 6) {
      alert("La contraseña debe tener al menos 6 caracteres.");
      return;
    }

    try {
      await usuariosService.cambiarPassword(user.id || user.usuarioId, newPassword);
      alert('Contraseña actualizada correctamente.');
    } catch (error) {
      console.error("Error al restablecer la contraseña:", error);
      alert("Ocurrió un error al restablecer la contraseña.");
    }
  };

  const handleGuardarPermisos = async () => {
    if (!selectedUser) return;
    setLoadingPermisos(true);
    try {
      const permisosToSave = Object.keys(permisosActivos).map(modulo => ({
        modulo,
        nivel: permisosActivos[modulo]
      }));
      await usuariosService.actualizarPermisosUsuario(selectedUser.id || selectedUser.usuarioId, permisosToSave.map((p: any) => p.modulo));
      alert('Permisos guardados correctamente.');
    } catch (error: any) {
      console.error('Error guardando permisos', error);
      alert(error.response?.data?.message || 'Error al guardar los permisos.');
    } finally {
      setLoadingPermisos(false);
    }
  };

  const usuariosFiltrados = usuarios.filter(u => {
    const q = search.toLowerCase();
    const matchBusqueda = u.nombre.toLowerCase().includes(q) || u.username.toLowerCase().includes(q);
    const matchRol = !filtroRol || u.rol === filtroRol;
    return matchBusqueda && matchRol;
  });

  if (selectedUser) {
    return (
      <div className="h-full flex flex-col relative overflow-hidden bg-gray-50/50">
        <div className="flex items-center gap-2 mb-6">
          <span className="text-gray-500 font-medium text-sm tracking-wide">SAE /</span>
          <span className="text-navy-900 font-bold text-sm tracking-wide">Usuarios</span>
        </div>
        
        <div className="flex gap-6 h-full pb-6 overflow-hidden">
          {/* Panel Izquierdo: Ficha del usuario */}
          <div className="w-80 flex-shrink-0 bg-white rounded-2xl shadow-sm border border-gray-100 p-8 flex flex-col items-center">
            <div className="w-24 h-24 rounded-full bg-navy-900 mx-auto flex items-center justify-center text-white text-3xl font-bold uppercase shadow-sm mb-6">
              {selectedUser.nombre.charAt(0)}
            </div>
            <h2 className="text-xl font-bold text-navy-900 text-center leading-tight mb-2">{selectedUser.nombre}</h2>
            <p className="text-gray-500 text-xs font-semibold uppercase tracking-wider mb-6">
              {selectedUser.rol === 'MAESTRA' ? 'DOCENTE' : selectedUser.rol}
            </p>
            
            <span className={`px-4 py-1.5 rounded-full text-xs font-bold mb-8 ${
              selectedUser.activo ? 'bg-emerald-50 text-emerald-600' : 'bg-red-50 text-red-600'
            }`}>
              {selectedUser.activo ? 'Cuenta Activa' : 'Cuenta Inactiva'}
            </span>

            <div className="w-full space-y-4 mt-auto">
              <button 
                onClick={() => handleRestablecerPassword(selectedUser)}
                className="w-full py-2.5 bg-white border border-gray-200 text-navy-700 font-medium rounded-xl hover:bg-gray-50 transition-colors text-sm"
              >
                Restablecer Contraseña
              </button>
              {selectedUser.activo ? (
                <button 
                  onClick={() => handleToggleEstado(selectedUser)}
                  className="w-full py-2.5 bg-white border border-red-200 text-red-600 font-medium rounded-xl hover:bg-red-50 transition-colors text-sm"
                >
                  Desactivar / Eliminar
                </button>
              ) : (
                <button 
                  onClick={() => handleToggleEstado(selectedUser)}
                  className="w-full py-2.5 bg-emerald-50 text-emerald-700 font-medium rounded-xl hover:bg-emerald-100 transition-colors text-sm"
                >
                  Reactivar Cuenta
                </button>
              )}
              <button 
                onClick={() => setSelectedUser(null)}
                className="w-full py-3 bg-navy-900 text-white font-medium rounded-xl hover:bg-navy-800 transition-colors text-sm flex items-center justify-center gap-2 mt-6"
              >
                ← Volver al listado
              </button>
            </div>
          </div>

          {/* Panel Derecho: Permisos */}
          <div className="flex-1 bg-white rounded-2xl shadow-sm border border-gray-100 flex flex-col overflow-hidden">
            <div className="p-6 border-b border-gray-100 flex justify-between items-center bg-white">
              <h3 className="font-bold text-lg text-navy-900">Permisos de Acceso a Módulos</h3>
              <div className="flex gap-3">
                <button 
                  type="button"
                  onClick={() => {
                    const defaultPerms: Record<string, 'NINGUNO' | 'lectura' | 'escritura'> = {};
                    modulosValidos.forEach(m => defaultPerms[m] = 'NINGUNO');
                    setPermisosActivos(defaultPerms);
                  }}
                  className="px-5 py-2 text-sm font-semibold text-gray-700 bg-white border border-gray-200 hover:bg-gray-50 rounded-xl transition-colors"
                  disabled={selectedUser.rol === 'ADMIN'}
                >
                  Default
                </button>
                <button 
                  type="button"
                  onClick={handleGuardarPermisos}
                  disabled={loadingPermisos || selectedUser.rol === 'ADMIN'}
                  className="px-6 py-2 text-sm font-semibold text-white bg-navy-900 hover:bg-navy-800 rounded-xl transition-colors disabled:opacity-50 shadow-sm"
                >
                  {loadingPermisos ? 'Guardando...' : 'Guardar cambios'}
                </button>
              </div>
            </div>
            
            <div className="flex-1 overflow-y-auto p-8 bg-white">
              {selectedUser.rol === 'ADMIN' && (
                <div className="mb-6 p-4 bg-blue-50 border border-blue-100 rounded-xl text-blue-800 text-sm">
                  <strong>Nota:</strong> Los usuarios con rol Administrador tienen acceso total e irrestricto al sistema. No es necesario ni posible configurar permisos individuales.
                </div>
              )}

              {loadingPermisos && selectedUser.rol !== 'ADMIN' ? (
                <div className="text-center py-10 text-gray-400 font-medium">Cargando permisos...</div>
              ) : (
                <div className="space-y-0">
                  {modulosValidos.map((modulo, idx) => (
                    <div key={modulo} className={`flex items-center justify-between py-5 ${idx !== modulosValidos.length - 1 ? 'border-b border-gray-50' : ''}`}>
                      <span className="text-gray-700 font-medium capitalize">{modulo.replace(/_/g, ' ')}</span>
                      <div className="flex items-center gap-8">
                        <label className="flex items-center gap-2.5 cursor-pointer">
                          <input 
                            type="radio" 
                            name={`permiso_${modulo}`} 
                            value="NINGUNO"
                            checked={permisosActivos[modulo] === 'NINGUNO'}
                            onChange={() => setPermisosActivos(prev => ({...prev, [modulo]: 'NINGUNO'}))}
                            disabled={selectedUser.rol === 'ADMIN'}
                            className="w-4 h-4 text-blue-600 focus:ring-blue-500 border-gray-300"
                          />
                          <span className="text-sm text-gray-600 font-medium">Ninguno</span>
                        </label>
                        <label className="flex items-center gap-2.5 cursor-pointer">
                          <input 
                            type="radio" 
                            name={`permiso_${modulo}`} 
                            value="lectura"
                            checked={permisosActivos[modulo] === 'lectura'}
                            onChange={() => setPermisosActivos(prev => ({...prev, [modulo]: 'lectura'}))}
                            disabled={selectedUser.rol === 'ADMIN'}
                            className="w-4 h-4 text-blue-600 focus:ring-blue-500 border-gray-300"
                          />
                          <span className="text-sm text-gray-600 font-medium">Lectura</span>
                        </label>
                        <label className="flex items-center gap-2.5 cursor-pointer">
                          <input 
                            type="radio" 
                            name={`permiso_${modulo}`} 
                            value="escritura"
                            checked={permisosActivos[modulo] === 'escritura'}
                            onChange={() => setPermisosActivos(prev => ({...prev, [modulo]: 'escritura'}))}
                            disabled={selectedUser.rol === 'ADMIN'}
                            className="w-4 h-4 text-blue-600 focus:ring-blue-500 border-gray-300"
                          />
                          <span className="text-sm text-gray-600 font-medium">Lectura y Edición</span>
                        </label>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col relative overflow-hidden">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-navy-800">Usuarios del sistema</h2>
          <p className="text-sm text-gray-500 mt-1">Gestiona los accesos, roles y permisos de tu personal.</p>
        </div>
        <div className="flex gap-4 items-center">
          <select 
            className="px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-navy-500 outline-none text-gray-700"
            value={mostrarInactivos ? 'inactivos' : 'activos'}
            onChange={(e) => setMostrarInactivos(e.target.value === 'inactivos')}
          >
            <option value="activos">Mostrar activos</option>
            <option value="inactivos">Mostrar inactivos (Eliminados)</option>
          </select>
          <button 
            className="flex items-center gap-2 px-4 py-2 bg-navy-600 text-white rounded-xl hover:bg-navy-700 transition-colors shadow-sm font-medium"
            onClick={() => setIsModalOpen(true)}
          >
            <Plus size={16} /> Nuevo usuario
          </button>
        </div>
      </div>

      <div className="flex gap-4 mb-6">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
          <input 
            type="text" 
            placeholder="Buscar por nombre o usuario..." 
            className="w-full pl-10 pr-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <select 
          className="px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none w-48"
          value={filtroRol}
          onChange={(e) => setFiltroRol(e.target.value)}
        >
          <option value="">Todos los roles</option>
          <option value="ADMIN">Administrador</option>
          <option value="GESTOR">Gestor</option>
          <option value="MAESTRA">Docente</option>
        </select>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden flex-1 flex flex-col">
        <div className="overflow-auto flex-1">
          <table className="w-full text-sm text-left">
            <thead className="bg-gray-50 border-b border-gray-200 sticky top-0 z-10">
              <tr>
                <th className="p-4 font-semibold text-gray-600">Usuario</th>
                <th className="p-4 font-semibold text-gray-600">Rol</th>
                <th className="p-4 font-semibold text-gray-600">Estado</th>
                <th className="p-4 font-semibold text-gray-600 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading ? (
                <tr>
                  <td colSpan={4} className="p-8 text-center text-gray-400">Cargando usuarios...</td>
                </tr>
              ) : usuariosFiltrados.length === 0 ? (
                <tr>
                  <td colSpan={4} className="p-8 text-center text-gray-400">No se encontraron usuarios.</td>
                </tr>
              ) : (
                usuariosFiltrados.map((user) => (
                  <tr key={user.id} className={`hover:bg-gray-50 transition-colors ${!user.activo ? 'bg-gray-50/50 opacity-70' : ''}`}>
                    <td className="p-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-navy-50 flex items-center justify-center text-navy-700 font-bold uppercase">
                          {user.nombre.charAt(0)}
                        </div>
                        <div>
                          <div className="font-bold text-navy-800">{user.nombre}</div>
                          <div className="text-xs text-gray-500">@{user.username}</div>
                        </div>
                      </div>
                    </td>
                    <td className="p-4">
                      <span className="flex items-center gap-1.5 text-gray-600 font-medium">
                        {user.rol === 'ADMIN' ? <Shield size={14} className="text-navy-600" /> : <UserCircle size={14} />}
                        {user.rol === 'MAESTRA' ? 'DOCENTE' : user.rol}
                      </span>
                    </td>
                    <td className="p-4">
                      <span className={`px-2 py-1 rounded text-xs font-semibold ${
                        user.activo ? 'bg-emerald-50 text-emerald-700' : 'bg-gray-100 text-gray-600'
                      }`}>
                        {user.activo ? 'Activo' : 'Inactivo'}
                      </span>
                    </td>
                    <td className="p-4 text-right">
                      <button 
                        onClick={() => setSelectedUser(user)}
                        className="px-3 py-1.5 text-xs font-medium text-navy-600 bg-navy-50 rounded-lg hover:bg-navy-100 transition-colors"
                      >
                        Gestionar Ficha
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal Nuevo Usuario */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-navy-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl w-full max-w-md shadow-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h3 className="text-lg font-bold text-navy-800">Crear Nuevo Usuario</h3>
              <button onClick={() => setIsModalOpen(false)} className="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-gray-100 transition-colors">
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleCrearUsuario} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nombre Completo</label>
                <input 
                  type="text" 
                  required
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={nuevoUsuario.nombre}
                  onChange={(e) => setNuevoUsuario({...nuevoUsuario, nombre: e.target.value})}
                  placeholder="Ej. Juan Pérez"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nombre de Usuario</label>
                <input 
                  type="text" 
                  required
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={nuevoUsuario.username}
                  onChange={(e) => setNuevoUsuario({...nuevoUsuario, username: e.target.value.toLowerCase().trim()})}
                  placeholder="Ej. juan.perez"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Contraseña Temporal</label>
                <div className="relative">
                  <input 
                    type={showPassword ? "text" : "password"} 
                    required
                    minLength={6}
                    className="w-full pl-4 pr-10 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                    value={nuevoUsuario.password}
                    onChange={(e) => setNuevoUsuario({...nuevoUsuario, password: e.target.value})}
                  />
                  <button 
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 focus:outline-none"
                  >
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Rol de Sistema</label>
                <select 
                  required
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500 outline-none"
                  value={nuevoUsuario.rol}
                  onChange={(e) => setNuevoUsuario({...nuevoUsuario, rol: e.target.value})}
                >
                  <option value="MAESTRA">Docente (MAESTRA)</option>
                  <option value="GESTOR">Gestor Administrativo</option>
                  <option value="ADMIN">Administrador</option>
                </select>
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
                  className="px-5 py-2.5 text-sm font-medium text-white bg-navy-600 hover:bg-navy-700 rounded-xl transition-colors shadow-sm"
                >
                  Crear Usuario
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
