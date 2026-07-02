import { Link, useLocation } from 'react-router-dom';
import { Home, Users, BookOpen, Shield, LogOut, Calendar, Award, BarChart3, History, Star, CreditCard, Heart, FileText, FileDown } from 'lucide-react';
import { useAuthStore } from '../../store/useAuthStore';

export function Sidebar() {
  const location = useLocation();
  const { user, logout } = useAuthStore();

  const navCategories = [
    {
      title: 'Principal',
      items: [
        { name: 'Dashboard', path: '/', icon: Home, roles: ['ADMIN', 'DIRECTOR', 'GESTOR', 'DOCENTE', 'MAESTRA'] },
      ]
    },
    {
      title: 'Académico',
      items: [
        { name: 'Directorio Escolar', path: '/alumnos', icon: Users, roles: ['ADMIN', 'DIRECTOR', 'GESTOR', 'DOCENTE', 'MAESTRA'] },
        { name: 'Padres & Tutores', path: '/tutores', icon: Heart, roles: ['ADMIN', 'DIRECTOR', 'GESTOR'] },
        { name: 'Grupos & Materias', path: '/grupos', icon: BookOpen, roles: ['ADMIN', 'DIRECTOR', 'GESTOR', 'DOCENTE', 'MAESTRA'] },
        { name: 'Calificaciones', path: '/calificaciones', icon: Award, roles: ['ADMIN', 'DIRECTOR', 'GESTOR', 'DOCENTE', 'MAESTRA'] },
        { name: 'Historial Académico', path: '/historial-academico', icon: FileText, roles: ['ADMIN', 'DIRECTOR', 'GESTOR', 'DOCENTE', 'MAESTRA'] },
        { name: 'Boletas', path: '/boleta', icon: FileDown, roles: ['ADMIN', 'DIRECTOR', 'GESTOR', 'DOCENTE', 'MAESTRA'] },
      ]
    },
    {
      title: 'Finanzas',
      items: [
        { name: 'Registro de Pagos', path: '/pagos', icon: CreditCard, roles: ['ADMIN', 'DIRECTOR', 'GESTOR'] },
        { name: 'Gestión de Becas', path: '/becas', icon: Star, roles: ['ADMIN', 'DIRECTOR', 'GESTOR'] },
        { name: 'Reportes Financieros', path: '/reportes', icon: BarChart3, roles: ['ADMIN', 'DIRECTOR'] },
      ]
    },
    {
      title: 'Sistema',
      items: [
        { name: 'Ciclo Escolar', path: '/ciclo-escolar', icon: Calendar, roles: ['ADMIN', 'DIRECTOR'] },
        { name: 'Usuarios', path: '/usuarios', icon: Shield, roles: ['ADMIN'] },
        { name: 'Bitácora', path: '/bitacora', icon: History, roles: ['ADMIN'] },
      ]
    }
  ];

  const userRole = user?.rol?.toUpperCase() || '';

  return (
    <aside className="w-[260px] bg-gradient-to-b from-navy-500 to-navy-700 text-white flex flex-col h-screen">
      <div className="p-6 flex items-center gap-3 border-b border-white/10">
        <div className="w-12 h-12 bg-white rounded-lg flex items-center justify-center p-1 overflow-hidden">
          <img src="/escudo.png" alt="Colegio San Diego Logo" className="w-full h-full object-contain" />
        </div>
        <div>
          <h2 className="font-bold tracking-wide">COLEGIO</h2>
          <p className="text-xs text-white/60">San Diego</p>
        </div>
      </div>

      <nav className="flex-1 py-4 overflow-y-auto">
        {navCategories.map((category, idx) => {
          const visibleItems = category.items.filter(item => !item.roles || item.roles.includes(userRole));
          
          if (visibleItems.length === 0) return null;

          return (
            <div key={idx} className="mb-4">
              <div className="text-[0.7rem] font-semibold tracking-wider text-white/40 px-5 pb-2 uppercase">
                {category.title}
              </div>
              
              {visibleItems.map((item) => {
                const Icon = item.icon;
                const isActive = location.pathname === item.path;
                
                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    className={`flex items-center gap-3 px-4 py-2 mx-3 my-1 rounded-xl text-sm font-medium transition-all ${
                      isActive 
                        ? 'bg-white/10 text-white shadow-[inset_3px_0_0_#CC0000]' 
                        : 'text-white/75 hover:bg-white/5 hover:text-white'
                    }`}
                  >
                    <Icon size={18} className={isActive ? 'text-crimson-400' : 'opacity-70'} />
                    {item.name}
                  </Link>
                );
              })}
            </div>
          );
        })}
      </nav>

      <div className="p-4 border-t border-white/10 flex items-center gap-3 bg-navy-800/50 relative group">
        <div className="w-9 h-9 rounded-full bg-crimson-500 flex items-center justify-center font-bold flex-shrink-0">
          {user?.nombre?.charAt(0) || 'U'}
        </div>
        <div className="flex-1 overflow-hidden">
          <p className="text-sm font-semibold truncate">{user?.nombre || 'Usuario'}</p>
          <p className="text-xs text-white/50 truncate">{user?.rol || 'Rol'}</p>
        </div>
        <button 
          onClick={logout}
          title="Cerrar sesión"
          className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-white/10 text-white/60 hover:text-white transition-colors"
        >
          <LogOut size={16} />
        </button>
      </div>
    </aside>
  );
}
