import { create } from 'zustand';

interface User {
  id: number;
  nombre: string;
  email: string;
  rol: string;
  permisos: Record<string, string>;
}

interface AuthState {
  token: string | null;
  user: User | null;
  isAuthenticated: boolean;
  login: (token: string, user: User) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>((set) => {
  // Inicializar estado desde localStorage si existe
  const storedToken = localStorage.getItem('sae_token');
  const storedUser = localStorage.getItem('sae_usuario');
  let initialUser = null;

  try {
    if (storedUser) {
      initialUser = JSON.parse(storedUser);
    }
  } catch (error) {
    console.error('Error parsing stored user', error);
  }

  return {
    token: storedToken,
    user: initialUser,
    isAuthenticated: !!storedToken,
    
    login: (token, user) => {
      localStorage.setItem('sae_token', token);
      localStorage.setItem('sae_usuario', JSON.stringify(user));
      set({ token, user, isAuthenticated: true });
    },
    
    logout: () => {
      localStorage.removeItem('sae_token');
      localStorage.removeItem('sae_usuario');
      set({ token: null, user: null, isAuthenticated: false });
    },
  };
});
