export interface NivelEducativo {
  [key: string]: any;
  nivelId: number;
  codigo: string;
  nombre: string;
  rvoe?: string;
  orden: number;
}

export interface Alumno {
  [key: string]: any;
  alumnoId?: number;
  id?: number; // fallback for current api responses
  matricula?: string;
  curp?: string;
  nombreCompleto?: string;
  nombre?: string; // fallback for current frontend
  fechaNacimiento?: string;
  sexo?: string;
  nivelId?: number;
  estado?: string;
  fechaBaja?: string;
  motivoBaja?: string;
  diaLimitePago?: number;
  personasAutorizadas?: any;
  observaciones?: string;
  nivel?: string | any;
  padres?: any[];
  padresLista?: any[];
  grado?: string;
  seccion?: string;
}

export interface Tutor {
  [key: string]: any;
  tutorId?: number;
  id?: number;
  nombreCompleto?: string;
  nombre?: string;
  correoElectronico?: string;
  correo?: string;
  telefono?: string;
  direccion?: string;
  rfc?: string;
  curp?: string;
  regimenFiscal?: string;
  usoCfdi?: string;
  direccionFiscal?: string;
  codigoPostal?: string;
  correoFacturacion?: string;
  requiereFactura?: boolean;
  tipoPagoHabitual?: string;
  saldoAFavor?: number;
  activo?: boolean;
  alumnos?: any[];
  pagos?: any[];
  facturas?: any[];
  movimientosSaldo?: any[];
  documentos?: any[];
}

export interface TutorAlumno {
  tutorAlumnoId?: number;
  tutorId: number;
  alumnoId: number;
  tipoRelacion: string;
  esResponsableFinanciero: boolean;
  puedeRecoger: boolean;
  recibeNotificaciones: boolean;
  tutor?: any;
  alumno?: any;
}
