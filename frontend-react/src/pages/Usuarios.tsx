import React, { useState, useEffect } from 'react';
import { Search, Plus, UserCircle, Shield, X, Key, Trash2, Power, Eye, EyeOff } from 'lucide-react';
import api from '../services/api';

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

  // Slide-over (Panel lateral) para Detalles/Permisos
  const [selectedUser, setSelectedUser] = useState<any>(null);

  const cargarUsuarios = async () => {
    setLoading(true);
    try {
      const res = await api.get('/usuarios', {
        params: { incluirInactivos: mostrarInactivos }
      });
      if (res.data) setUsuarios(res.data);
    } catch (error) {
      console.error('Error cargando usuarios', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    cargarUsuarios();
  }, [mostrarInactivos]);

  const handleCrearUsuario = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.post('/usuarios', nuevoUsuario);
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
      if (user.activo) {
        if (!window.confirm(`¿Estás seguro de desactivar a ${user.nombre}? No podrá iniciar sesión.`)) return;
        await api.delete(`/usuarios/${user.id || user.usuarioId}`);
      } else {
        await api.put(`/usuarios/${user.id || user.usuarioId}/reactivar`, {});
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
      await api.put(`/usuarios/${user.id || user.usuarioId}`, { password: newPassword });
      alert("Contraseña restablecida correctamente.");
    } catch (error) {
      console.error("Error al restablecer la contraseña:", error);
      alert("Ocurrió un error al restablecer la contraseña.");
    }
  };

  const usuariosFiltrados = usuarios.filter(u => {
    const q = search.toLowerCase();
    const matchBusqueda = u.nombre.toLowerCase().includes(q) || u.username.toLowerCase().includes(q);
    const matchRol = !filtroRol || u.rol === filtroRol;
    return matchBusqueda && matchRol;
  });

  return (
    <div className="h-full flex flex-col relative overflow-hidden">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-navy-800">Usuarios del sistema</h2>
          <p className="text-sm text-gray-500 mt-1">Gestiona los accesos, roles y permisos de tu personal.</p>
        </div>
        <div className="flex gap-4 items-center">
          <label className="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
            <input 
              type="checkbox" 
              checked={mostrarInactivos}
              onChange={(e) => setMostrarInactivos(e.target.checked)}
              className="rounded border-gray-300 text-navy-600 focus:ring-navy-600"
            />
            Mostrar inactivos
          </label>
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

      {/* Slide-over (Panel lateral) para Gestionar Ficha */}
      <div className={`fixed inset-y-0 right-0 w-96 bg-white shadow-2xl transform transition-transform duration-300 ease-in-out z-40 border-l border-gray-200 ${selectedUser ? 'translate-x-0' : 'translate-x-full'}`}>
        {selectedUser && (
          <div className="h-full flex flex-col">
            <div className="p-6 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h3 className="font-bold text-lg text-navy-800">Ficha de Usuario</h3>
              <button onClick={() => setSelectedUser(null)} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 flex-1 overflow-y-auto">
              <div className="text-center mb-8">
                <div className="w-20 h-20 rounded-full bg-gradient-to-br from-navy-500 to-navy-700 mx-auto flex items-center justify-center text-white text-3xl font-bold uppercase shadow-md mb-3">
                  {selectedUser.nombre.charAt(0)}
                </div>
                <h2 className="text-xl font-bold text-navy-800">{selectedUser.nombre}</h2>
                <p className="text-gray-500 mb-2">@{selectedUser.username}</p>
                <span className={`px-3 py-1 rounded-full text-xs font-semibold inline-block ${
                  selectedUser.activo ? 'bg-emerald-50 text-emerald-700' : 'bg-gray-100 text-gray-600'
                }`}>
                  {selectedUser.activo ? 'Cuenta Activa' : 'Cuenta Inactiva'}
                </span>
              </div>

              <div className="space-y-4">
                <div className="bg-gray-50 rounded-xl p-4">
                  <div className="text-sm text-gray-500 mb-1">Rol de Sistema</div>
                  <div className="font-semibold text-navy-800 flex items-center gap-2">
                    {selectedUser.rol === 'ADMIN' ? <Shield size={16} className="text-navy-600" /> : <UserCircle size={16} />}
                    {selectedUser.rol === 'MAESTRA' ? 'DOCENTE' : selectedUser.rol}
                  </div>
                </div>

                <div className="border-t border-gray-100 pt-6 mt-6 space-y-3">
                  <h4 className="text-sm font-bold text-gray-400 uppercase tracking-wider mb-4">Acciones Administrativas</h4>
                  
                  {selectedUser.activo ? (
                    <>
                      <button 
                        onClick={() => handleRestablecerPassword(selectedUser)}
                        className="w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-white border border-gray-200 text-navy-700 font-medium rounded-xl hover:bg-gray-50 transition-colors"
                      >
                        <Key size={16} /> Restablecer Contraseña
                      </button>
                      <button 
                        onClick={() => handleToggleEstado(selectedUser)}
                        className="w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-red-50 text-red-600 font-medium rounded-xl hover:bg-red-100 transition-colors"
                      >
                        <Trash2 size={16} /> Desactivar Usuario
                      </button>
                    </>
                  ) : (
                    <button 
                      onClick={() => handleToggleEstado(selectedUser)}
                      className="w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-emerald-50 text-emerald-700 font-medium rounded-xl hover:bg-emerald-100 transition-colors"
                    >
                      <Power size={16} /> Reactivar Cuenta
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
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
