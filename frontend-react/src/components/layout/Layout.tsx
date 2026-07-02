import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';

export function Layout() {
  return (
    <div className="flex h-screen print:h-auto bg-[#F8FAFE] print:bg-white overflow-hidden print:overflow-visible">
      <div className="print:hidden">
        <Sidebar />
      </div>
      <main className="flex-1 flex flex-col h-full print:h-auto overflow-hidden print:overflow-visible print:block">
        {/* Placeholder for a top header if needed */}
        <header className="h-16 bg-white border-b border-gray-100 flex items-center px-6 justify-between print:hidden">
            <h1 className="text-xl font-semibold text-gray-800">Sistema Administrativo Escolar</h1>
        </header>
        
        <div className="flex-1 overflow-auto print:overflow-visible p-6 print:p-0">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
