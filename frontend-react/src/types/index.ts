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

export interface CicloEscolar {
  cicloId: number;
  nombre: string;
  fechaInicio: string;
  fechaFin: string;
  activo: boolean;
}

export interface Grupo {
  [key: string]: any;
  grupoId?: number;
  id?: number;
  cicloId: number;
  nivelId: number;
  grado: string;
  seccion: string;
  nombre: string;
  docenteTitularId?: number | null;
  cupoMaximo?: number | null;
  materias?: any[];
}

export interface Materia {
  [key: string]: any;
  materiaId: number;
  nivelId: number;
  claveSep?: string | null;
  nombre: string;
  tipo: string;
  cuentaParaPromedio: boolean;
}

export interface Calificacion {
  [key: string]: any;
  calificacionId: number;
  alumnoId: number;
  grupoMateriaId: number;
  periodoId: number;
  tipoEvaluacion: string;
  valorNumerico?: number | null;
  valorCualitativo?: string | null;
  textoObservacion?: string | null;
  cuentaParaPromedio: boolean;
  modificadaMotivo?: string | null;
}

export interface Pago {
  [key: string]: any;
  pagoId: number;
  alumnoId?: number | null;
  tutorId?: number | null;
  fechaPago: string;
  montoTotal: number | string;
  metodoPago: string;
  aplicadoASaldo: boolean;
  observaciones?: string | null;
  registradoPor?: number | null;
}

export interface BecaCatalogo {
  [key: string]: any;
  becaId: number;
  nombreBeca: string;
  criterio: string;
  porcentaje: number | string;
  descripcion?: string | null;
}

export interface BecaAsignada {
  [key: string]: any;
  asignacionId: number;
  alumnoId: number;
  becaId: number;
  cicloId: number;
  estado: string;
  fechaAsignacion: string;
  beca?: BecaCatalogo;
  alumno?: Alumno;
}

export interface Usuario {
  [key: string]: any;
  usuarioId?: number;
  id?: number;
  nombreUsuario: string;
  nombreCompleto: string;
  correo?: string | null;
  telefono?: string | null;
  activo: boolean;
  roles?: any[];
  permisos?: any;
}

export interface Tarifa {
  [key: string]: any;
  tarifaId: number;
  cicloId: number;
  nivelId: number;
  concepto: string;
  monto: number | string;
  descripcion?: string | null;
  activa: boolean;
}

export interface HistorialAcademico {
  alumno: Alumno;
  calificaciones: Calificacion[];
  promedioGeneral?: number;
}

