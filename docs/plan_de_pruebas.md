# Plan de Pruebas - Sistema Administrativo Escolar (SAE)

Este documento detalla las pruebas críticas que deben realizarse módulo por módulo antes de la entrega final del sistema. El objetivo es asegurar que los flujos principales (Happy Paths) y los casos borde más comunes funcionen correctamente.

> [!IMPORTANT]
> Se recomienda realizar estas pruebas en un entorno limpio (base de datos de pruebas o con datos de ejemplo) para evitar afectar información real.

---

## 1. Módulo de Autenticación y Seguridad
**Objetivo:** Garantizar el acceso seguro y el correcto manejo de roles.

- [ ] **Inicio de Sesión:** Ingresar con credenciales válidas e inválidas. Validar que los mensajes de error sean claros.
- [ ] **Control de Roles:** Ingresar con un usuario con rol limitado (ej. solo lectura o cobranza) y verificar que no pueda acceder ni modificar áreas restringidas (ej. configuración de ciclos).
- [ ] **Expiración de Sesión:** Verificar que al expirar el token, el sistema redirija correctamente al login.

---

## 2. Módulo de Control Escolar (Ciclos y Grupos)
**Objetivo:** Validar la estructura base donde se inscribirán los alumnos.

- [ ] **Gestión de Ciclos:**
  - Crear un nuevo ciclo escolar.
  - Activar el ciclo (verificar que solo un ciclo pueda estar activo a la vez).
  - Configurar los planes de pago por defecto del ciclo.
- [ ] **Gestión de Grupos:**
  - Crear grupos (Preescolar, Primaria, Secundaria).
  - Asignar cupos máximos y verificar que el sistema respete este límite al inscribir.
  - Asignar profesores/tutores a cada grupo.

---

## 3. Módulo de Alumnos y Tutores
**Objetivo:** Asegurar la correcta gestión de los expedientes y sus relaciones.

- [ ] **Alta de Tutores:**
  - Crear un tutor con todos sus datos de facturación (RFC, Régimen, etc.).
- [ ] **Alta de Alumnos:**
  - Inscribir un alumno nuevo asociándolo al tutor previamente creado.
  - Verificar que el alumno aparezca correctamente en la lista general y en su grupo.
- [ ] **Expediente del Alumno:**
  - Editar la información personal del alumno.
  - Verificar la correcta carga de la vista "Expediente del Alumno" sin errores de interfaz.
- [ ] **Bajas y Reactivaciones:**
  - Dar de baja temporal a un alumno y verificar su estado.
  - Reactivar al alumno y validar que sus procesos (como pagos) se reanuden.

---

## 4. Módulo de Finanzas y Pagos (Crítico)
**Objetivo:** Validar la integridad de los ingresos, asignación de planes y cobros.

- [ ] **Asignación de Planes y Calendario:**
  - Confirmar que al inscribir un alumno, se le asigne su plan de pagos.
  - Verificar que el calendario de pagos (las 10 o 12 colegiaturas) se haya generado automáticamente y con las fechas/montos correctos.
  - Validar el prorrateo para inscripciones tardías (si aplica).
- [ ] **Asignación de Becas:**
  - Asignar una beca (ej. 50%) a un alumno y revisar que el monto de sus colegiaturas pendientes se recalcule inmediatamente.
- [ ] **Registro de Pagos:**
  - Cobrar una colegiatura normal.
  - Cobrar una colegiatura con recargos (simular o seleccionar fecha vencida).
  - **Prueba de regresión:** Verificar que en la ventana emergente NO aparezca el error *"Sin plan de pagos"* para alumnos que sí tienen uno asignado.
- [ ] **Generación de Recibos:**
  - Confirmar que al registrar un pago se genere el recibo/ticket y sea imprimible.

---

## 5. Módulo Académico (Calificaciones)
**Objetivo:** Asegurar el registro y consulta de desempeño estudiantil.

- [ ] **Registro de Calificaciones:**
  - Seleccionar un grupo y registrar calificaciones parciales para varios alumnos.
- [ ] **Boletas:**
  - Generar la boleta de un alumno y validar que el cálculo de promedios sea correcto.
  - Revisar la vista del historial académico de años/ciclos anteriores.

---

## 6. Módulo de Reportes y Auditoría
**Objetivo:** Validar la trazabilidad de los datos y el resumen financiero.

- [ ] **Reportes Financieros:**
  - Generar un corte de caja (ingresos del día).
  - Exportar la lista de deudores y verificar que la información cuadre con los saldos pendientes.
- [ ] **Bitácora (Logs):**
  - Acceder a la Bitácora y verificar que las acciones críticas (como registrar pagos o dar de baja un alumno) hayan quedado registradas con el usuario y fecha correspondientes.

> [!TIP]
> **Recomendación para la entrega:** Te sugiero abrir 2 ventanas simultáneas durante tu presentación: una con el rol de Administrador y otra (en incógnito) con el rol de Cajera/Control Escolar, para demostrar la robustez del sistema y la separación de permisos.
