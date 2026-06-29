import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from './store/useAuthStore';
import { Layout } from './components/layout/Layout';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { Alumnos } from './pages/Alumnos';
import { Grupos } from './pages/Grupos';
import { Usuarios } from './pages/Usuarios';
import { CicloEscolar } from './pages/CicloEscolar';
import { Calificaciones } from './pages/Calificaciones';
import { Reportes } from './pages/Reportes';
import { Bitacora } from './pages/Bitacora';
import { Becas } from './pages/Becas';
import { Pagos } from './pages/Pagos';
import { Tutores } from './pages/Tutores';
import { TutorPerfil } from './pages/TutorPerfil';

function App() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={!isAuthenticated ? <Login /> : <Navigate to="/" />} />
        
        {/* Protected Routes inside Layout */}
        <Route path="/" element={isAuthenticated ? <Layout /> : <Navigate to="/login" />}>
          <Route index element={<Dashboard />} />
          <Route path="alumnos" element={<Alumnos />} />
          <Route path="grupos" element={<Grupos />} />
          <Route path="calificaciones" element={<Calificaciones />} />
          <Route path="reportes" element={<Reportes />} />
          <Route path="becas" element={<Becas />} />
          <Route path="pagos" element={<Pagos />} />
          <Route path="bitacora" element={<Bitacora />} />
          <Route path="usuarios" element={<Usuarios />} />
          <Route path="ciclo-escolar" element={<CicloEscolar />} />
          <Route path="tutores" element={<Tutores />} />
          <Route path="tutores/:id" element={<TutorPerfil />} />
          {/* Add more routes here as we migrate them */}
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
