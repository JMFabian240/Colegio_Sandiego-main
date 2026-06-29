import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';

export function Layout() {
  return (
    <div className="flex h-screen bg-[#F8FAFE] overflow-hidden">
      <Sidebar />
      <main className="flex-1 flex flex-col h-full overflow-hidden">
        {/* Placeholder for a top header if needed */}
        <header className="h-16 bg-white border-b border-gray-100 flex items-center px-6 justify-between">
            <h1 className="text-xl font-semibold text-gray-800">Sistema Administrativo Escolar</h1>
        </header>
        
        <div className="flex-1 overflow-auto p-6">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
