# Requisitos del Sistema

*Proyecto:* **Proyecto Colegio San Diego**
*Elaborado y extraído por:* **José Manuel Fabian Hernández**

---

## 1. Requisitos Funcionales

### Módulo 1 — Acceso y Gestión de Usuarios

| ID | Descripción | Tipo |
|---|---|---|
| RF-01 | El administrador debe  poder crear una cuenta para un nuevo colaborador, ingresando nombre, rol (administrador, gestor administrativo, docente) y contraseña, y habilitar el acceso al sistema con los permisos correspondientes a su nivel. | Usuario |
| RF-02 | El administrador debe  poder consultar el listado de todos los usuarios registrados en el sistema, sin necesidad de parámetros adicionales, y visualizar en pantalla el nombre, rol, estado de la cuenta (activa/desactivada) y la fecha del último acceso de cada colaborador. | Usuario |
| RF-03 | El administrador debe  poder modificar los permisos de acceso de un empleado ya registrado, seleccionando la cuenta del usuario y el tipo de acceso permitido por módulo (solo lectura o lectura y edición), y aplicar los cambios de forma inmediata restringiendo o habilitando el acceso del empleado a los módulos indicados. | Usuario |
| RF-04 | El gestor administrativo debe  poder gestionar el panel administrativo, permitiéndole una lectura global para poder realizar revisiones, emitir reportes y hacer cotejo de información financiera y escolar, además de la captura y registro de pagos diarios, pero sin permisos de configuración crítica o alteración de bases de datos. | Usuario |
| RF-05 | El docente debe  poder consultar los datos básicos de un alumno, buscando por nombre, grado o grupo, y visualizar únicamente el nombre del alumno, grado, grupo y personas autorizadas para recogerlo, sin acceso a información de pagos ni datos fiscales. | Usuario |
| RF-06 | El administrador, gestor administrativo y docente deben  poder cerrar sesión manualmente desde cualquier pantalla del sistema, seleccionando la opción de cierre de sesión, y el sistema debe redirigir a la pantalla de inicio de sesión eliminando los datos de la sesión activa. | Usuario |
| RF-07 | El administrador debe  poder eliminar la cuenta de un colaborador que ya no labora en el plantel, seleccionando el usuario por nombre o rol, y revocar su acceso al sistema de forma inmediata. | Usuario |

### Módulo 2 — Seguridad y Bitácora

| ID | Descripción | Tipo |
|---|---|---|
| RF-08 | El sistema debe  registrar automáticamente cada acción de creación, modificación o eliminación realizada sobre expedientes, pagos o usuarios, almacenando el nombre del usuario que ejecutó la acción, la fecha y hora, el registro afectado y el tipo de cambio realizado, y permitir al usuario administrador consultar o exportar ese historial en cualquier momento. | Sistema |
| RF-09 | El administrador debe poder consultar el historial de la bitácora en pantalla, visualizando los registros de las acciones de los usuarios ordenados cronológicamente. | Usuario |
| RF-10 | El administrador debe poder exportar el historial de la bitácora de acciones en un formato estructurado (ej. Excel o PDF) filtrando por rango de fechas o por usuario específico. | Usuario |

### Módulo 3 — Gestión de Padres/Tutores

| ID | Descripción | Tipo |
|---|---|---|
| RF-11 | El administrador y gestor administrativo deben  poder registrar el perfil de un padre o tutor de forma independiente, ingresando nombre completo, dirección, RFC, régimen fiscal, teléfono, correo electrónico, tipo de pago habitual, CURP del alumno asociado y RVOE del nivel escolar, e indicar si requiere factura electrónica, y el sistema debe guardar el perfil disponible para su vinculación con uno o más alumnos. | Usuario |
| RF-12 | El administrador y gestor administrativo deben  poder vincular a un padre de familia con más de un alumno, ingresando el identificador del padre y los alumnos correspondientes, y asociar todos los hijos a un único perfil de pagos del tutor. | Usuario |
| RF-13 | El administrador y gestor administrativo deben poder modificar los datos de un padre o tutor ya registrado, seleccionando el perfil e ingresando la información corregida (contacto o datos fiscales), reflejando los cambios inmediatamente sin afectar el historial de facturas previas. | Usuario |

### Módulo 4 — Gestión de Alumnos

| ID | Descripción | Tipo |
|---|---|---|
| RF-14 | El administrador y gestor administrativo deben  poder registrar un nuevo alumno en el sistema, ingresando nombre completo, CURP, matrícula, grado, grupo, nivel educativo (preescolar, primaria, secundaria o bachillerato), fecha de nacimiento y personas autorizadas para recogerlo, y almacenar el expediente del alumno vinculado a los datos del padre o tutor correspondiente. | Usuario |
| RF-15 | El administrador y gestor administrativo deben  poder registrar a un alumno que se incorpora a mitad de ciclo escolar, indicando la fecha de ingreso y los conceptos aplicables (inscripción, material, uniforme), y calcular automáticamente el cobro proporcional correspondiente al tiempo restante del ciclo, generando el calendario de pagos ajustado. | Usuario |
| RF-16 | El administrador y gestor administrativo deben  poder revertir la baja temporal de un alumno, seleccionando el expediente del alumno dado de baja e ingresando el motivo (acuerdo de pago, convenio institucional u otro), y el sistema debe restaurar el estatus del alumno a activo, reactivando la generation de nuevas colegiaturas con la tarifa regular al 100% (sin aplicar becas previas perdidas por morosidad) y notificar el cambio en la bitácora del sistema. | Usuario |
| RF-17 | El administrador y gestor administrativo deben  poder consultar el expediente de un alumno, buscando por nombre, matrícula o CURP, y desplegar en pantalla todos los datos registrados del alumno en una vista detallada. | Usuario |
| RF-18 | El administrador y gestor administrativo deben  poder modificar los datos de un alumno ya registrado, seleccionando el expediente por nombre o matrícula e ingresando la información corregida (grado, grupo o personas autorizadas), y reflejar los cambios de forma inmediata en el sistema. | Usuario |
| RF-19 | El administrador y gestor administrativo deben  poder filtrar el listado de alumnos, seleccionando uno o más criterios combinados (nivel educativo, grado y grupo), y desplegar en pantalla únicamente los alumnos que coincidan con los filtros aplicados, con opción de exportar el resultado. | Usuario |
| RF-20 | El administrador y gestor administrativo deben  poder desactivar el expediente de un alumno que egresó o se dio de baja, buscándolo por nombre o matrícula, y ocultarlo de las vistas activas sin eliminarlo permanentemente, conservando su historial para auditorías futuras. | Usuario |
| RF-21 | El administrador debe  poder ejecutar el cierre de ciclo escolar, seleccionando el ciclo a cerrar y confirmando la acción. El sistema debe validar el estado financiero de todos los alumnos; aquellos con adeudos pendientes serán retenidos en un estado de 'Transición Pendiente' y excluidos de la promoción automática. Para los alumnos regulares, el sistema los promoverá masivamente al siguiente grado, marcará como egresados a quienes concluyen el nivel y generará la estructura de cobros para el nuevo ciclo. | Usuario |
| RF-22 | El administrador debe  poder ejecutar la baja definitiva de un alumno, seleccionando el expediente con estatus de 'Baja Temporal' que no haya concretado un acuerdo de pago, y el sistema debe formalizar la salida cerrando el expediente para el ciclo vigente y registrando la acción en la bitácora de auditoría. | Usuario |

### Módulo 5 — Gestión de Becas

| ID | Descripción | Tipo |
|---|---|---|
| RF-23 | El administrador y gestor administrativo deben  poder registrar en el catálogo del sistema los tipos de beca disponibles, ingresando nombre de la beca, criterio de asignación (tiempo de inscripción, calificación o beca por hermanos) y porcentaje de descuento, y almacenar el catálogo de becas para su uso en los procesos de inscripción. | Usuario |
| RF-24 | El administrador y gestor administrativo deben  poder consultar los tipos de beca registrados en el catálogo del sistema, seleccionando el tipo de beca por nombre, y el sistema debe reflejar en pantalla las becas que están registradas. | Usuario |
| RF-25 | El administrador y gestor administrativo deben  poder modificar los tipos de beca registrados en el catálogo del sistema, seleccionando el tipo de beca por nombre y actualizando el criterio de asignación, el porcentaje de descuento u otro atributo, y el sistema debe reflejar los cambios en el catálogo de forma inmediata para los procesos de inscripción futuros, sin alterar becas ya asignadas en ciclos activos. | Usuario |
| RF-26 | El administrador debe  poder asignar una beca a un alumno durante el proceso de inscripción del ciclo escolar, seleccionando el tipo de beca y el porcentaje aplicable, y aplicar el descuento de forma automática a los pagos del alumno durante todo el ciclo escolar. Si la acción es realizada por un Gestor Administrativo, el sistema no aplicará el descuento inmediatamente, sino que generará una 'Solicitud de Beca Pendiente', la cual mantendrá la colegiatura al 100% hasta que sea evaluada por el nivel administrativo superior. | Usuario |
| RF-27 | El administrador debe  tener acceso a un panel de 'Autorizaciones Pendientes' donde pueda visualizar todas las solicitudes de asignación y retiro de becas generadas por los Gestores Administrativos. El Administrador debe poder Aprobar (aplicando los cambios financieros en el sistema y recalculando cobros) o Rechazar (eliminando la solicitud), y el sistema debe registrar la decisión en la bitácora de auditoría detallando quién solicitó y quién autorizó. | Usuario |
| RF-28 | El administrador debe  poder retirar la beca asignada a un alumno, seleccionando el expediente por nombre o matrícula e ingresando el motivo del retiro (mora reincidente u otro), y el sistema debe actualizar el monto de colegiatura del alumno reflejando el nuevo valor sin descuento a partir del siguiente periodo de pago. Si la acción es intentada por un Gestor Administrativo, el sistema no alterará el cobro actual, sino que generará una 'Solicitud de Retiro de Beca Pendiente', adjuntando el motivo escrito por el gestor para su posterior evaluación. | Usuario |
| RF-29 | El sistema debe  detectar automáticamente cuando un alumno acumula 3 meses consecutivos de adeudo sin pago registrado y retirar la beca. Esta acción debe ejecutarse como la primera transacción del proceso de morosidad, recalculando los montos de los pagos futuros y el adeudo histórico sin el descuento, previo a cualquier cambio de estado académico del alumno. Se generará una notificación al usuario administrador con el detalle del retiro. | Sistema |

### Módulo 6 — Gestión de Colegiaturas

| ID | Descripción | Tipo |
|---|---|---|
| RF-30 | El administrador y gestor administrativo deben  poder configurar los montos de colegiatura, inscripción, aranceles y materiales para un nuevo ciclo escolar, ingresando el identificador del ciclo escolar y las tarifas por nivel educativo (preescolar, primaria, secundaria o bachillerato), y aplicar los nuevos montos únicamente a los registros del ciclo indicado sin modificar los históricos. El sistema solicitará confirmación expresa antes de guardar los nuevos montos y registrará el cambio en la bitácora de auditoría. | Usuario |
| RF-31 | El administrador y gestor administrativo deben  poder asignar el plan de pago de un alumno al momento del registro, seleccionando entre el plan (a 10 meses o a 12 meses), y generar automáticamente el calendario de vencimientos correspondiente, incluyendo el pago doble de diciembre en el plan de 12 meses (que cubre diciembre del año en curso y enero del siguiente). | Usuario |
| RF-32 | El administrador debe  poder configurar una ventana de promoción por inscripción temprana, ingresando la fecha de inicio, fecha de fin y el porcentaje o tipo de beca que se otorgará a los padres que liquiden en ese periodo, y aplicar automáticamente el beneficio a los alumnos que cumplan la condición dentro del plazo establecido. | Usuario |
| RF-33 | El sistema debe  aplicar automáticamente un recargo de $400 pesos al monto de la colegiatura cuando el pago se registre después del quinto día del mes, sin requerir intervención manual del administrador, y reflejar el nuevo monto total en el historial de pagos del alumno. | Sistema |

### Módulo 7 — Registro y Control de Pagos

| ID | Descripción | Tipo |
|---|---|---|
| RF-34 | El administrador y gestor administrativo deben  poder registrar un pago realizado por un padre de familia, ingresando el tipo de pago (inscripción, arancel, material, uniforme o colegiatura), el monto, la fecha de pago y el método utilizado (transferencia, depósito o tarjeta), y actualizar automáticamente el estado del adeudo del alumno en el sistema. | Usuario |
| RF-35 | El administrador y gestor administrativo deben  poder adjuntar el comprobante digital de un pago al expediente del padre, cargando el archivo (imagen o PDF) y asociándolo al registro de pago correspondiente, y permitir su consulta o descarga en cualquier momento posterior. | Usuario |
| RF-36 | El administrador y gestor administrativo deben  poder registrar un pago adelantado de colegiatura para un alumno, ingresando el número de meses a adelantar, el monto total y el método de pago utilizado (transferencia, depósito o tarjeta), y marcar automáticamente como liquidados los meses futuros correspondientes, previniendo que se generen alertas de deudores o recargos erróneos en los meses cubiertos. | Usuario |
| RF-37 | El administrador y el gestor administrativo deben  poder modificar el recargo de $400 pesos aplicado a un alumno, seleccionando el registro del recargo correspondiente e ingresando el motivo de la modificación (acuerdo previo con el tutor u otro), y el sistema debe actualizar el monto total del adeudo reflejando el ajuste en el historial de pagos. | Usuario |
| RF-38 | El sistema debe  rastrear independientemente el plazo de liquidación para conceptos de inicio de ciclo (Inscripción, Materiales, Uniformes). Al cumplirse los 60 días naturales desde el inicio del ciclo escolar sin registrarse el pago total, el sistema debe cambiar el estado de estos conceptos a 'Vencido', bloquear el acceso del alumno a evaluaciones, transitar su estatus a 'Baja Temporal' y notificar al Administrador. | Sistema |
| RF-39 | El sistema debe  identificar automáticamente a un alumno que acumula 3 meses consecutivos de adeudo sin pago registrado, cambiar el estado del alumno a 'Baja Temporal' y generar una notificación interna para el administrador. Mientras el alumno permanezca en este estado, el sistema suspenderá la generación automática de nuevas colegiaturas mensuales, manteniendo intacto el adeudo acumulado calculado previamente. | Sistema |
| RF-40 | El sistema debe  generar alertas visuales automáticas en el panel principal (Dashboard), identificando pagos próximos a vencer, pérdida de becas y cumplimiento de plazos de 60 días, para informar al personal administrativo y permitir una gestión oportuna sin depender de correos externos. | Sistema |

### Módulo 8 — Historial de Pagos

| ID | Descripción | Tipo |
|---|---|---|
| RF-41 | El administrador y gestor administrativo deben  poder consultar el historial de pagos de un padre de familia, buscando por nombre del alumno o nombre del tutor, y visualizar en pantalla una línea de tiempo con todos los pagos realizados, montos, fechas, estados (pagado, pendiente, vencido) y saldos restantes. | Usuario |
| RF-42 | El administrador y gestor administrativo deben  poder consultar el estado de cuenta familiar consolidado de un tutor con múltiples hijos, buscando por nombre del tutor, y visualizar en pantalla la deuda total de la familia desglosada por alumno; además debe poder distribuir y asignar un único comprobante de pago entre los conceptos pendientes de los distintos hermanos, registrando los pagos de forma simultánea. | Usuario |

### Módulo 9 — Direcctorio de datos fiscales
| ID | Descripción | Tipo |
| :--- | :--- | :--- |
| RF-43 | El administrador y gestor administrativo deben poder registrar los datos fiscales asociados al perfil de un tutor (RFC, régimen fiscal, código postal, uso de CFDI) activando opcionalmente la bandera de requerimiento de facturación externa, y el sistema debe almacenar esta información vinculada a los futuros cobros del tutor. | Usuario |
| RF-44 | El administrador y gestor administrativo deben poder modificar los datos fiscales de un tutor ya registrado, actualizando su información (RFC, régimen fiscal, código postal, uso de CFDI) o alternando el estado de la bandera de facturación, y reflejar los cambios de forma inmediata sin afectar los comprobantes de pago emitidos en el pasado. | Usuario |
| RF-45 | El administrador y gestor administrativo deben poder consultar los datos fiscales de un tutor, buscando por nombre o RFC, y visualizar en pantalla el detalle de los datos ingresados junto con el estado actual (activo/inactivo) de su requerimiento de facturación. | Usuario |
| RF-46 | El administrador y gestor administrativo deben poder generar un reporte tabular de tutores, sin necesidad de parámetros adicionales, y el sistema debe exportar un listado consolidado exclusivamente con los datos fiscales de aquellos que tengan la bandera de requerimiento de facturación activa. | Usuario |

### Módulo 10 — Reportes

| ID | Descripción | Tipo |
|---|---|---|
| RF-47 | El administrador y gestor administrativo deben  poder generar un reporte de los pagos registrados en el día actual, sin necesidad de parámetros adicionales, y visualizar o imprimir un desglose con el nombre de cada alumno, monto pagado y método de pago, más un total global del día, exportable en formato Excel o PDF. | Usuario |
| RF-48 | El administrador y gestor administrativo deben  poder generar un reporte de ingresos de un mes determinado, seleccionando el mes y año deseado, y obtener un documento exportable en Excel o PDF con el desglose de pagos por alumno y la suma total del periodo. | Usuario |
| RF-49 | El administrador y gestor administrativo deben  poder generar un reporte financiero de un ciclo escolar completo, seleccionando el ciclo (ej. 2026-2027), y visualizar o exportar en Excel o PDF un resumen de ingresos totales, alumnos activos y pagos realizados durante ese periodo. | Usuario |
| RF-50 | El administrador y gestor administrativo deben  poder consultar la lista de deudores, filtrando por mes o periodo, y visualizar en pantalla un listado agrupado por tutor que muestre el nombre del padre de familia, la deuda consolidada total de la familia (suma de todos sus hijos), los nombres de los alumnos con adeudo y los días de retraso, facilitando la gestión de cobranza. | Usuario |
| RF-51 | El administrador y gestor administrativo deben  poder consultar la lista de alumnos con derecho a examen restringido por adeudo, indicando el periodo de evaluación, y el sistema debe cruzar el historial de pagos con el calendario de evaluaciones y generar la lista de alumnos afectados, exportable en PDF o Excel. | Usuario |
| RF-52 | El administrador y gestor administrativo deben  poder generar un reporte de todos los padres de familia que requieren factura electrónica, sin necesidad de parámetros adicionales, y visualizar o exportar un listado con nombre completo, RFC, régimen fiscal, dirección, CURP del alumno asociado y tipo de pago habitual, en formato Excel o PDF. | Usuario |

### Módulo 11 — Registro de Calificaciones

| ID | Descripción | Tipo |
|---|---|---|
| RF-53 | El administrador, gestor administrativo y docente deben  poder registrar la evaluación trimestral de un alumno de preescolar, seleccionando el expediente e ingresando observaciones y recomendaciones en texto para el trimestre correspondiente, y almacenarlas vinculadas al ciclo escolar activo sin requerir calificación numérica. | Usuario |
| RF-54 | El administrador, gestor administrativo y docente deben  poder registrar las calificaciones de un alumno de primaria, seleccionando el expediente e ingresando la calificación numérica por materia para los tres trimestres, y almacenarlas generando automáticamente el promedio final del ciclo. | Usuario |
| RF-55 | El administrador, gestor administrativo y docente deben  poder registrar las calificaciones de un alumno de secundaria, seleccionando el expediente por nombre o matrícula e ingresando las calificaciones por materia para cada bloque (Bloque 1, Bloque 2, Bloque 3 y calificación final), y almacenarlas vinculadas al perfil del alumno y al ciclo escolar activo. | Usuario |
| RF-56 | El administrador, gestor administrativo y docente deben  poder registrar las calificaciones de un alumno de bachillerato, seleccionando el expediente por nombre o matrícula e ingresando las calificaciones por materia para cada bimestre del semestre en curso, y almacenarlas vinculadas al perfil del alumno y al ciclo escolar activo. | Usuario |
| RF-57 | El administrador, gestor administrativo y docente deben  poder registrar la calificación de un alumno en los clubes extracurriculares (inglés, computación, danza), seleccionando el club correspondiente e ingresando la calificación del periodo, y almacenarla de forma separada a las materias curriculares para su inclusión en la boleta interna del plantel. | Usuario |
| RF-58 | El administrador, gestor administrativo y docente deben  poder registrar la evaluación de la materia Taller de un alumno, seleccionando dicha materia e ingresando la escala cualitativa ('A' para Acreditado o 'NA' para No Acreditado), y almacenarla en el historial sin que afecte el cálculo numérico del promedio general. | Usuario |
| RF-59 | El administrador, gestor administrativo y docente deben  poder modificar una calificación ya registrada de un alumno, seleccionando el expediente, el periodo y la materia correspondiente e ingresando la calificación corregida con un motivo de modificación, y el sistema debe actualizar el registro, reflejar el cambio en la boleta del alumno y registrar la modificación en la bitácora de auditoría. | Usuario |

### Módulo 12 — Generación y Consulta de Boletas

| ID | Descripción | Tipo |
|---|---|---|
| RF-60 | El docente debe  poder consultar las calificaciones de un alumno, buscando por nombre, grado o grupo, y visualizar únicamente las calificaciones del periodo activo sin acceso a datos de pagos, información fiscal ni historial de ciclos anteriores. | Usuario |
| RF-61 | El sistema debe  generar formatos de boleta dinámicos, validando el nivel educativo del alumno, y emitir un PDF que incluya espacio para firmas de padres; en caso de preescolar, el sistema debe mostrar observaciones en lugar de calificaciones numéricas para su entrega en junta trimestral, y en los demás niveles incluir calificaciones por materia, calificaciones de clubes extracurriculares (inglés, computación, danza) y promedio general. | Sistema |
| RF-62 | El sistema debe  identificar automáticamente a los alumnos con adeudo de colegiatura pendiente al momento de registrar calificaciones de examen, cruzando el estado de pago del alumno con el periodo de evaluación activo, y mostrar una alerta visible al usuario administrador indicando que el alumno no puede presentar examen hasta regularizar su situación. | Sistema |

### Módulo 13 — Historial Académico

| ID | Descripción | Tipo |
|---|---|---|
| RF-63 | El administrador y gestor administrativo deben  poder consultar el historial de calificaciones de un alumno, buscando por nombre o matrícula, y visualizar en pantalla todas las calificaciones registradas organizadas por ciclo escolar, periodo y materia, incluyendo clubes extracurriculares. | Usuario |
| RF-64 | El administrador y gestor administrativo deben  poder consultar el historial académico completo de un alumno a lo largo de varios ciclos escolares, seleccionando el expediente por nombre o matrícula, y visualizar en pantalla las calificaciones organizadas por ciclo, nivel, grado y periodo, incluyendo alumnos ya egresados o desactivados. | Usuario |

---

## 2. Requisitos No Funcionales

### Módulo 1 — Rendimiento

| ID | Descripción | Tipo |
|---|---|---|
| RNF-01 | El sistema debe completar la carga inicial de la aplicación y presentar la pantalla principal en un tiempo no mayor a 5 segundos, garantizando su viabilidad en equipos de escritorio con hardware básico (procesador de doble núcleo, 4 GB de RAM) y sin conexión a internet requerida. | Producto |
| RNF-02 | El sistema debe responder a cualquier acción del usuario (clic, búsqueda, filtro o navegación entre pantallas) en un tiempo máximo de 3 segundos, evitando percepciones de lentitud durante el uso cotidiano del sistema administrativo. | Producto |
| RNF-03 | El sistema debe generar y mostrar cualquier reporte (diario, mensual o por ciclo escolar) en un tiempo no mayor a 10 segundos cuando la base de datos contenga hasta 200 alumnos activos; en caso de superar ese tiempo, el sistema muestra un indicador de progreso al usuario. | Producto |

### Módulo 2 — Capacidad y Escalabilidad

| ID | Descripción | Tipo |
|---|---|---|
| RNF-04 | La arquitectura de la base de datos debe estar diseñada para soportar al menos 5,000 expedientes de alumnos y 50,000 registros de pagos, permitiendo el crecimiento sostenido de la institución a lo largo de múltiples ciclos escolares sin requerir cambios estructurales ni pérdida de rendimiento. | Producto |
| RNF-05 | El sistema debe soportar al menos 5 usuarios con sesiones activas de forma simultánea sin presentar errores, bloqueos ni pérdida de datos, considerando el número actual de personal administrativo del colegio. | Producto |

### Módulo 3 — Disponibilidad y Confiabilidad

| ID | Descripción | Tipo |
|---|---|---|
| RNF-06 | El sistema debe operar en su totalidad —carga de datos, registro de pagos, generación de reportes y gestión de expedientes— sin requerir ningún tipo de conexión a internet activa, garantizando su funcionamiento continuo independientemente de la conectividad del plantel. | Producto |
| RNF-07 | El sistema debe preservar la integridad de los archivos de datos ante un cierre abrupto de la aplicación o un corte de energía, asegurando que ningún registro de pago o expediente quede en estado corrupto o incompleto. | Producto |
| RNF-08 | El administrador y gestor administrativo deben poder generar un respaldo manual completo de la base de datos, exportando los archivos necesarios a una ruta local o dispositivo externo (USB), de forma que la información pueda restaurarse en caso de fallo del equipo. | Organizacional |
| RNF-09 | El sistema debe conservar de forma permanente los registros históricos de todos los ciclos escolares. Los alumnos egresados o dados de baja se desactivan, pero sus expedientes académicos y financieros no se eliminan, garantizando su disponibilidad para auditorías futuras. | Organizacional |
| RNF-10 | Los archivos de comprobantes de pago cargados (imágenes y PDF) deben almacenarse de forma persistente en el sistema, vinculados al expediente del alumno, sin depender de medios físicos externos como memorias USB. | Producto |
| RNF-11 | El sistema debe renombrar automáticamente cada archivo de comprobante subido por los usuarios, asignándole un identificador único universal (UUID) antes de almacenarlo en el disco del servidor, para evitar colisiones de nombres o sobreescrituras accidentales en la red local. | Producto |
| RNF-12 | El sistema debe ejecutar automáticamente un respaldo completo de la base de datos y del directorio de comprobantes de forma diaria, comprimiendo los archivos y subiéndolos automáticamente a una cuenta institucional en la nube (Google Drive o OneDrive), garantizando la recuperación ante un fallo físico catastrófico del servidor local. | Organizacional |

### Módulo 4 — Seguridad

| ID | Descripción | Tipo |
|---|---|---|
| RNF-13 | El sistema debe requerir usuario y contraseña para acceder a cualquier funcionalidad. Las contraseñas se almacenan cifradas mediante un algoritmo de hash seguro (bcrypt) y el sistema bloquea el acceso tras 5 intentos de inicio de sesión fallidos consecutivos, notificando al usuario administrador. | Producto |
| RNF-14 | El sistema debe garantizar que cada usuario solo pueda acceder a las funcionalidades correspondientes a su rol asignado, impidiendo técnicamente —no solo visualmente— que un usuario estándar realice acciones reservadas al administrador. | Producto |
| RNF-15 | El sistema debe proteger los datos personales y fiscales de los padres de familia (RFC, dirección, régimen fiscal, CURP) conforme a los principios de la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP), limitando su visualización únicamente a usuarios con nivel de acceso administrativo. | Externo |
| RNF-16 | El sistema debe registrar un log de auditoría de todas las operaciones críticas (registro de pagos, asignación o retiro de becas, baja de alumnos, modificación de permisos, modificación de los montos de pago), indicando fecha, hora y nombre del usuario que realizó la acción. Este log solo es visible para el usuario administrador. | Organizacional |

### Módulo 5 — Usabilidad

| ID | Descripción | Tipo |
|---|---|---|
| RNF-17 | El sistema debe presentar una interfaz clara y sin saturación visual, utilizando íconos reconocibles, etiquetas descriptivas y flujos de navegación simples, de forma que personal administrativo con nivel básico de manejo tecnológico pueda operar el sistema sin requerir capacitación extensa. | Producto |
| RNF-18 | El sistema debe utilizar los colores institucionales del Colegio San Diego (azul marino RGB(5,14,119), azul claro RGB(136,208,248), rojo RGB(249,3,0) y verde RGB(33,129,32)) y mostrar el escudo oficial en las pantallas principales, manteniendo coherencia con la imagen del plantel en toda la interfaz. | Producto |
| RNF-19 | El sistema debe mostrar mensajes claros de confirmación antes de ejecutar acciones irreversibles (eliminar, desactivar, borrar) y mensajes descriptivos de error cuando una operación no pueda completarse, indicando la causa y la acción sugerida al usuario. | Producto |
| RNF-20 | El sistema debe presentar las consultas más frecuentes (lista de deudores, ingresos del mes, pagos del día y alumnos con examen restringido) como accesos directos visibles desde la pantalla principal, de forma que el administrador pueda acceder a cualquiera de ellas en no más de dos clics desde el inicio de sesión. | Producto |

### Módulo 6 — Portabilidad y Mantenibilidad

| ID | Descripción | Tipo |
|---|---|---|
| RNF-21 | El sistema debe poder instalarse en distintas computadoras de escritorio mediante un archivo ejecutable o copiando los archivos necesarios desde un dispositivo USB, sin requerir configuraciones avanzadas ni instalación de dependencias externas. Debe ser compatible con Windows 10 u 11. | Producto |
| RNF-22 | El sistema debe contar con documentación técnica suficiente (diagrama entidad-relación, diccionario de datos, descripción de módulos y guía de instalación) entregada junto con el sistema, que permita a un desarrollador externo realizar tareas de mantenimiento o ampliación sin necesidad de contactar al equipo original. | Organizacional |
| RNF-23 | El sistema debe operar bajo arquitectura cliente-servidor en red local (LAN): la computadora de la directora funcionará como el servidor que aloja la base de datos principal, y las demás computadoras del personal se conectarán como clientes a esa base de datos a través de la red local del colegio, sin requerir internet. | Producto |

### Módulo 7 — Exportación e Interoperabilidad

| ID | Descripción | Tipo |
|---|---|---|
| RNF-24 | El sistema debe permitir exportar cualquier reporte generado tanto en formato Excel (.xlsx, compatible con Microsoft Excel 2016 o posterior) como en PDF (compatible con Adobe Acrobat Reader), garantizando que el contenido sea idéntico en ambos formatos y que el PDF sea directamente imprimible. | Producto |
| RNF-25 | El sistema debe proporcionar una plantilla Excel estandarizada y una funcionalidad de carga masiva que valide la integridad de los datos (CURPs únicas, estructura de niveles, asociación Padre-Hijo) antes de la inserción, rechazando el archivo si detecta errores críticos para garantizar la consistencia en el 'Año Cero'. | Organizacional |
| RNF-26 | Todos los reportes tabulares y listados generados por el sistema, haciendo especial énfasis en el Directorio Fiscal y el Historial de Pagos, deben ser exportables nativamente en formatos estructurados estándar (.csv y .xlsx). Esta exportación debe preservar la integridad de las columnas (cabeceras y tipos de datos) para garantizar su compatibilidad directa e importación masiva en software contable de terceros (ej. CONTPAQi, Aspel COI) sin requerir transformaciones manuales previas por parte del usuario. | Producto |

