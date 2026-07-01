import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/useAuthStore';
import api from '../services/api';

export function Login() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  
  const login = useAuthStore((state) => state.login);
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      // Endpoint from original API (auth.js / login)
      const response = await api.post('/auth/login', {
        username: username,
        password: password
      });
      
      // api interceptor returns response.data directly, so response IS the body
      const body: any = response;
      if (body && body.token) {
        login(body.token, body.usuario);
        navigate('/');
      } else if (body && body.data && body.data.token) {
        login(body.data.token, body.data.usuario);
        navigate('/');
      } else {
        setError('Error al iniciar sesión');
      }
    } catch (err: any) {
      setError(err.response?.data?.message || 'Usuario o contraseña incorrectos');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#001429] flex flex-col justify-center py-12 sm:px-6 lg:px-8 relative overflow-hidden">
      {/* Decorative background circles */}
      <div className="absolute -top-24 -right-24 w-96 h-96 rounded-full bg-crimson-600/20 blur-3xl"></div>
      <div className="absolute -bottom-24 -left-24 w-96 h-96 rounded-full bg-navy-500/30 blur-3xl"></div>

      <div className="sm:mx-auto sm:w-full sm:max-w-md relative z-10">
        <div className="bg-white py-10 px-6 shadow-2xl sm:rounded-[2rem] sm:px-12">
          <div className="text-center mb-10">
            <div className="mx-auto w-24 h-24 mb-6 flex items-center justify-center">
               <img src="/escudo.png" alt="Colegio San Diego Logo" className="w-full h-full object-contain" />
            </div>
            <h2 className="text-2xl font-bold text-navy-800 tracking-tight">Bienvenido de vuelta</h2>
            <p className="text-sm text-gray-500 mt-2">Ingresa tus credenciales para acceder</p>
          </div>

          <form className="space-y-6" onSubmit={handleLogin}>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Usuario
              </label>
              <input
                type="text"
                required
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500/20 focus:border-navy-500 outline-none transition-all"
                placeholder="admin"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Contraseña
              </label>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-navy-500/20 focus:border-navy-500 outline-none transition-all"
                placeholder="••••••••"
              />
            </div>

            {error && (
              <div className="p-3 rounded-xl bg-crimson-50 text-crimson-600 text-sm font-medium text-center border border-crimson-100">
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full flex justify-center py-3.5 px-4 border border-transparent rounded-xl shadow-sm text-sm font-bold text-white bg-crimson-600 hover:bg-crimson-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-crimson-500 transition-all disabled:opacity-50"
            >
              {loading ? 'Iniciando...' : 'Iniciar Sesión'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
