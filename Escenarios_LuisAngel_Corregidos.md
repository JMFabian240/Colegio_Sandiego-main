
# Escenarios de Caso de Uso — Luis Ángel Reyes Mendoza
## Renumerados y corregidos conforme al documento de Requisitos vigente

> Este documento contiene los 13 escenarios elaborados por Luis Ángel Reyes Mendoza, con la numeración RF-XX corregida para que coincida con el documento de requisitos actual, y con las correcciones de contenido acordadas para los 3 escenarios de Bitácora (RF-08, RF-09 y RF-10). Al final se incluye una sección de **Notas pendientes** con los puntos que aún requieren una decisión.

---

## RF-01: Crear cuenta para un nuevo colaborador

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Administrador |
| **Objetivo** | Registrar a un nuevo empleado en el sistema, otorgándole credenciales de acceso y asignando automáticamente los permisos correspondientes a sus funciones en la institución. |
| **Flujo Principal** | 1. El Administrador ingresa al módulo de Gestión de Usuarios.<br>2. Selecciona la opción para crear una nueva cuenta o registrar colaborador.<br>3. El sistema despliega un formulario de registro en pantalla.<br>4. El Administrador ingresa el nombre, selecciona el rol (administrador, gestor administrativo o docente) y asigna una contraseña.<br>5. El Administrador confirma la acción haciendo clic en "Guardar".<br>6. El sistema valida que la información sea correcta.<br>7. El sistema crea la cuenta y habilita el acceso con los permisos predefinidos para el rol seleccionado.<br>8. El sistema muestra un mensaje informando que la cuenta se creó exitosamente y regresa a la lista de usuarios. |
| **Flujo Alterno** | **A. Datos incompletos:**<br>1. En el paso 6, el sistema detecta que el Administrador no ingresó uno de los datos solicitados (nombre, rol o contraseña).<br>2. El sistema resalta el campo faltante y muestra una alerta indicando que todos los campos son obligatorios.<br>3. El Administrador completa la información y repite el paso 5.<br><br>**B. Usuario duplicado:**<br>1. En el paso 6, el sistema detecta que el nombre de usuario ya existe en la base de datos.<br>2. El sistema advierte que el registro está duplicado y pide usar un identificador distinto.<br>3. El Administrador ajusta el dato y repite el paso 5. |
| **Precondiciones** | El Administrador debe haber iniciado sesión exitosamente en la plataforma y contar con los privilegios requeridos para acceder al panel de Gestión de Usuarios. |
| **Postcondiciones** | La cuenta del colaborador queda activa en el sistema. El nuevo usuario puede iniciar sesión de inmediato y visualizar únicamente los módulos y funciones que su rol le permite. |
| **Reglas de negocio involucradas** | • La creación de cuentas es una función exclusiva y restringida al actor **Administrador**.<br>• Los roles asignables deben estar estrictamente limitados a las opciones predefinidas: **administrador, gestor administrativo o docente**.<br>• Los permisos del sistema se heredan de manera automática a la cuenta creada con base en el rol seleccionado. |

---

## RF-03: Modificar permisos de acceso
*(antes etiquetado como RF-02)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Administrador |
| **Objetivo** | Actualizar y configurar el nivel de acceso de un colaborador ya existente en la plataforma, especificando si tiene permisos de solo lectura o lectura y edición para cada módulo. |
| **Flujo Principal** | 1. El Administrador ingresa al módulo de Gestión de Usuarios.<br>2. Selecciona la cuenta del empleado que desea modificar desde el listado de usuarios.<br>3. El sistema despliega el perfil del usuario con su configuración actual de accesos por módulo.<br>4. El Administrador ajusta el tipo de acceso para los módulos deseados (seleccionando "solo lectura" o "lectura y edición").<br>5. El Administrador hace clic en "Guardar cambios".<br>6. El sistema valida la solicitud y actualiza la base de datos.<br>7. El sistema aplica las nuevas restricciones o habilitaciones de manera inmediata.<br>8. El sistema muestra un mensaje de confirmación de éxito y regresa al perfil del usuario o listado general. |
| **Flujo Alterno** | **A. Selección de cuenta inactiva:**<br>1. En el paso 2, el Administrador selecciona una cuenta que previamente fue desactivada o eliminada.<br>2. El sistema deshabilita las opciones de edición de permisos y muestra una alerta indicando que la cuenta debe ser reactivada antes de modificar sus accesos.<br>3. El Administrador decide si reactivar la cuenta o cancelar la operación.<br><br>**B. Error de conexión al guardar:**<br>1. En el paso 6, el sistema experimenta una pérdida de conexión o error en la base de datos.<br>2. El sistema muestra un mensaje de error indicando que los cambios no pudieron guardarse.<br>3. El Administrador debe reintentar la acción una vez restablecida la conexión. |
| **Precondiciones** | El Administrador debe haber iniciado sesión con credenciales válidas y el usuario cuyos permisos se van a modificar debe estar previamente registrado en el sistema. |
| **Postcondiciones** | La cuenta del empleado queda actualizada con los nuevos privilegios. Si el empleado tiene una sesión activa en ese momento, los cambios en sus permisos de lectura o edición se reflejan de forma inmediata al intentar acceder a los módulos afectados. |
| **Reglas de negocio involucradas** | • La modificación de permisos granulares es una facultad exclusiva del actor **Administrador**.<br>• Los niveles de acceso configurables por módulo están limitados estrictamente a dos estados: **solo lectura** o **lectura y edición**.<br>• Los cambios de acceso no requieren que el usuario afectado cierre e inicie sesión nuevamente; la restricción o habilitación es de aplicación inmediata. |

---

## RF-04: Gestionar panel administrativo
*(antes etiquetado como RF-03)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Gestor Administrativo |
| **Objetivo** | Acceder a una vista global del sistema para consultar información, emitir reportes, cotejar datos financieros/escolares y registrar pagos diarios, manteniendo la integridad de las configuraciones críticas de la plataforma. |
| **Flujo Principal** | 1. El Gestor Administrativo inicia sesión y el sistema lo redirige al panel administrativo principal.<br>2. El Gestor navega por las secciones habilitadas (información escolar, información financiera, captura de pagos).<br>3. El Gestor realiza consultas o cotejo de información financiera y académica de los alumnos.<br>4. El Gestor captura y registra un pago diario en el sistema.<br>5. El sistema procesa el pago y actualiza los saldos correspondientes.<br>6. El Gestor genera y emite un reporte basado en la información consultada o capturada.<br>7. El sistema entrega el reporte solicitado en pantalla o para descarga. |
| **Flujo Alterno** | **A. Intento de acceso a funciones críticas:**<br>1. Durante la navegación (paso 2), el Gestor intenta hacer clic en un área de configuración crítica o de alteración de base de datos (por ejemplo, eliminar un historial o cambiar permisos de usuarios).<br>2. El sistema oculta estas opciones por defecto o muestra un mensaje de "Acceso denegado: Permisos insuficientes" si intenta acceder por ruta directa.<br>3. El Gestor es devuelto a la pantalla segura de su panel administrativo. |
| **Precondiciones** | El Gestor Administrativo debe haber iniciado sesión exitosamente con su cuenta activa y su rol debe estar configurado correctamente en el sistema. |
| **Postcondiciones** | Los pagos capturados quedan registrados en la base de datos y los reportes son emitidos exitosamente. El sistema mantiene protegidas y sin alteraciones todas las configuraciones críticas y estructuras de la base de datos. |
| **Reglas de negocio involucradas** | • El **Gestor Administrativo** tiene habilitada la lectura global del sistema y permisos de escritura limitados exclusivamente al **registro y captura de pagos diarios**.<br>• El sistema debe bloquear por completo cualquier intento de este perfil por alterar bases de datos, eliminar registros históricos o modificar configuraciones críticas (funciones exclusivas del Administrador). |

---

## RF-05: Consultar datos básicos de alumno
*(antes etiquetado como RF-04)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Docente |
| **Objetivo** | Permitir al personal docente buscar y visualizar la información general y de seguridad (personas autorizadas para recogerlo) de un alumno, garantizando la privacidad de los datos financieros y fiscales de la familia. |
| **Flujo Principal** | 1. El Docente inicia sesión y navega a la sección de consulta de alumnos.<br>2. El Docente ingresa un criterio en la barra de búsqueda (nombre del alumno, grado o grupo).<br>3. El Docente ejecuta la búsqueda.<br>4. El sistema consulta la base de datos y despliega una lista de resultados coincidentes.<br>5. El Docente selecciona el perfil del alumno deseado.<br>6. El sistema muestra en pantalla únicamente los datos básicos: nombre del alumno, grado, grupo y lista de personas autorizadas para recogerlo. |
| **Flujo Alterno** | **A. Búsqueda sin resultados:**<br>1. En el paso 4, el sistema no encuentra coincidencias con el texto, grado o grupo ingresado.<br>2. El sistema muestra un mensaje indicando: "No se encontraron alumnos con los criterios proporcionados".<br>3. El Docente modifica los parámetros de búsqueda y vuelve al paso 3. |
| **Precondiciones** | El Docente debe tener una sesión activa en el sistema. Los expedientes de los alumnos deben estar previamente registrados en la base de datos escolar. |
| **Postcondiciones** | El Docente visualiza la información requerida de manera exitosa. No se realiza ninguna modificación en la base de datos (operación de solo lectura). |
| **Reglas de negocio involucradas** | • El perfil **Docente** tiene bloqueado por defecto el acceso a los módulos financieros y de facturación.<br>• Al consultar un expediente, el sistema debe filtrar y ocultar proactivamente cualquier información relacionada con pagos, adeudos, becas, RFC o datos fiscales del tutor. |

---

## RF-06: Cerrar sesión manualmente
*(antes etiquetado como RF-05)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Administrador, Gestor Administrativo y Docente |
| **Objetivo** | Terminar de forma segura la sesión activa del usuario en la plataforma, protegiendo la privacidad de la información y evitando accesos no autorizados en el equipo utilizado. |
| **Flujo Principal** | 1. El Usuario se encuentra navegando en cualquier pantalla del sistema.<br>2. El Usuario hace clic en el botón u opción de "Cerrar sesión" (ubicado en el menú principal o perfil).<br>3. El sistema recibe la solicitud de terminación de sesión.<br>4. El sistema invalida las credenciales de la sesión activa y elimina de manera segura los datos temporales asociados.<br>5. El sistema redirige al Usuario a la pantalla principal de inicio de sesión (Login). |
| **Flujo Alterno** | **A. Error de comunicación con el servidor local durante el cierre:**<br>1. En el paso 3, ocurre una falla de comunicación con el servidor local (LAN) que impide confirmar el cierre de sesión.<br>2. El sistema, por seguridad, cierra la sesión de forma local en el equipo del usuario.<br>3. El sistema redirige a la pantalla de inicio de sesión y, una vez restablecida la comunicación con el servidor, sincroniza la invalidación de la sesión. |
| **Precondiciones** | El Usuario (ya sea Administrador, Gestor o Docente) debe tener una sesión previamente iniciada y activa en el sistema. |
| **Postcondiciones** | La sesión queda completamente cerrada e invalidada. Si el usuario intenta retroceder a una pantalla anterior del sistema, el sistema deniega el acceso y solicita ingresar nuevamente el usuario y contraseña. |
| **Reglas de negocio involucradas** | • La opción para cerrar sesión debe ser un componente global, es decir, debe estar visible y accesible desde **cualquier pantalla** del sistema.<br>• El sistema está obligado a purgar/eliminar los datos de la sesión activa para garantizar la seguridad de la información escolar y financiera. |

> **Nota de corrección:** se ajustó el lenguaje original ("token de autenticación", "navegador") por terminología compatible con la arquitectura de escritorio cliente-servidor en LAN definida en RNF-23. Ver Notas pendientes.

---

## RF-07: Eliminar cuenta de colaborador
*(antes etiquetado como RF-06)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Administrador |
| **Objetivo** | Revocar de manera inmediata el acceso a la plataforma de un empleado que ya no labora en el plantel educativo, protegiendo la integridad del sistema. |
| **Flujo Principal** | 1. El Administrador ingresa al módulo de Gestión de Usuarios.<br>2. El Administrador utiliza la barra de búsqueda para localizar al usuario por su nombre, o aplica un filtro por rol.<br>3. El sistema muestra la cuenta correspondiente en el listado.<br>4. El Administrador selecciona la cuenta y hace clic en la opción "Eliminar" (o "Desactivar").<br>5. El sistema despliega un cuadro de diálogo de confirmación ("¿Está seguro de que desea eliminar a este usuario? Esta acción revocará su acceso inmediatamente").<br>6. El Administrador hace clic en "Confirmar".<br>7. El sistema ejecuta la baja en la base de datos y revoca los accesos.<br>8. El sistema muestra un mensaje de éxito ("Cuenta eliminada/desactivada correctamente") y actualiza la lista de usuarios. |
| **Flujo Alterno** | **A. Cancelación de la operación:**<br>1. En el paso 5, el Administrador decide no proceder (por ejemplo, notó que seleccionó a la persona equivocada).<br>2. El Administrador hace clic en "Cancelar".<br>3. El sistema cierra el cuadro de diálogo sin realizar ningún cambio y regresa al listado general.<br><br>**B. Intento de eliminar la propia cuenta:**<br>1. En el paso 4, el Administrador intenta eliminar su propio usuario (el que tiene la sesión iniciada).<br>2. El sistema bloquea la acción y muestra una alerta: "Acción denegada: No puede eliminar su propia cuenta activa".<br>3. La operación se cancela automáticamente. |
| **Precondiciones** | El Administrador debe haber iniciado sesión con sus credenciales y la cuenta del colaborador a eliminar debe existir previamente en el sistema. |
| **Postcondiciones** | La cuenta seleccionada queda inhabilitada. Si el usuario afectado se encuentra navegando dentro del sistema en ese preciso momento, su sesión caduca inmediatamente y es expulsado a la pantalla de inicio de sesión. |
| **Reglas de negocio involucradas** | • La eliminación o desactivación de cuentas es un privilegio exclusivo del actor **Administrador**.<br>• El sistema debe garantizar que la revocación del acceso sea de efecto **inmediato**. |

---

## RF-02: Consultar listado de usuarios
*(antes etiquetado como RF-07)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Administrador |
| **Objetivo** | Acceder a un directorio global de todos los colaboradores registrados en la plataforma para auditar quiénes tienen acceso, su nivel de permisos y cuándo fue su última actividad. |
| **Flujo Principal** | 1. El Administrador hace clic para ingresar al módulo de Gestión de Usuarios.<br>2. El sistema procesa la solicitud y consulta la base de datos automáticamente, sin requerir parámetros de búsqueda iniciales.<br>3. El sistema despliega en pantalla una tabla o lista con todos los usuarios registrados.<br>4. El Administrador visualiza la información estructurada de cada colaborador: nombre completo, rol asignado, estado de la cuenta (activa o desactivada) y fecha/hora de su último acceso. |
| **Flujo Alterno** | **A. Error de carga o pérdida de conexión:**<br>1. En el paso 2, el sistema no logra recuperar la información de la base de datos debido a un fallo de red.<br>2. El sistema muestra un mensaje de error: "No se pudo cargar el listado de usuarios. Por favor, verifique su conexión e intente nuevamente".<br>3. El Administrador recarga la página o vuelve a hacer clic en el módulo. |
| **Precondiciones** | El Administrador debe tener una sesión activa con los privilegios correspondientes. Deben existir registros de usuarios en la base de datos (como mínimo, la cuenta del propio Administrador). |
| **Postcondiciones** | El Administrador visualiza la lista detallada y actualizada del personal. Al ser una operación de solo lectura, la base de datos no sufre ninguna alteración. |
| **Reglas de negocio involucradas** | • La visualización del listado completo de personal (incluyendo estados y últimas conexiones) es un permiso estrictamente reservado para el actor **Administrador**.<br>• El sistema debe registrar y mostrar con precisión la fecha del último acceso, la cual se actualiza automáticamente cada vez que un usuario realiza un inicio de sesión exitoso. |

---

## RF-08: Gestión de Bitácora — Registro automático
*(sin etiqueta numérica en el original; contenido corregido — ver discusión sobre estructura de la bitácora)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Sistema (registro automático) / Administrador (consulta posterior) |
| **Objetivo** | Capturar y persistir de forma automática e inmutable todas las acciones críticas (creación, actualización o eliminación) ejecutadas sobre expedientes, pagos o usuarios en la plataforma. |
| **Flujo Principal** | 1. Un usuario (o el propio Sistema, en procesos automáticos como RF-29, RF-33 o RF-39) completa una acción de creación, modificación o eliminación sobre un expediente, pago o usuario.<br>2. El Sistema detecta la transacción exitosa.<br>3. El Sistema captura en segundo plano: usuario que ejecutó la acción (o "Sistema" si fue automática), fecha y hora exacta, módulo/registro afectado, tipo de cambio realizado y, cuando aplique, el valor anterior y el valor nuevo del dato modificado.<br>4. El Sistema inserta esta información como un nuevo registro inmutable en la tabla de bitácora. |
| **Puntos de Extensión** | Ninguno. |
| **Flujo Alterno** | **A. Fallo de persistencia:**<br>1. En el paso 4, el Sistema detecta un error al intentar guardar en la tabla de bitácora.<br>2. El Sistema ejecuta un rollback (aborta) de la acción original del usuario para mantener la integridad.<br>3. El Sistema muestra un error técnico: "Error interno: No se pudo verificar la transacción de seguridad". |
| **Precondiciones** | Un usuario o un proceso automático del sistema debe haber iniciado una acción de creación, modificación o eliminación sobre expedientes, pagos o usuarios. |
| **Postcondiciones** | La base de datos conserva un rastro inmutable de la operación, con usuario (o "Sistema"), fecha y hora, módulo/registro afectado y tipo de cambio realizado, disponible para su consulta (RF-09) y exportación (RF-10) por parte del Administrador. |
| **Reglas de negocio involucradas** | • El registro de la bitácora debe ser **automático** y no puede ser apagado ni pausado por ningún usuario.<br>• Este log solo es visible para el usuario **Administrador** (RNF-16).<br>• Cuando la acción modifique un valor existente (ej. monto de un pago, permisos de un usuario), el registro debe incluir el **valor anterior y el valor nuevo** para permitir auditorías detalladas. |

> **Corrección aplicada:** la Postcondición original mencionaba "el Administrador obtiene un documento exportado", lo cual corresponde al caso de uso RF-10, no a este. Se sustituyó por una postcondición consistente con el registro automático. Además se agregó al Flujo Principal y a las Reglas de negocio la captura de "valor anterior → valor nuevo".

---

## RF-09: Consultar Historial de Bitácora
*(sin etiqueta numérica en el original; contenido corregido)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Administrador |
| **Objetivo** | Permitir al Administrador auditar visualmente el historial de movimientos registrados en la plataforma. |
| **Flujo Principal** | 1. El Administrador ingresa al módulo de "Seguridad y Bitácora".<br>2. El Sistema consulta la base de datos ordenando los registros de forma cronológica descendente (más recientes primero).<br>3. El Sistema despliega en pantalla la tabla con el historial de movimientos, mostrando para cada registro: usuario (o "Sistema"), fecha y hora, módulo/registro afectado y tipo de cambio. |
| **Puntos de Extensión** | **A. Exportar historial:** Opcionalmente, después de visualizar la tabla (paso 3), el Administrador puede hacer clic en "Exportar". Esto pausa el flujo actual y ejecuta el caso de uso RF-10 (Exportar Reporte de Bitácora). |
| **Flujo Alterno** | **A. Base de datos sin actividad:**<br>1. En el paso 2, el Sistema detecta que la tabla de bitácora está vacía.<br>2. En el paso 3, el Sistema muestra la estructura de la tabla vacía con el mensaje: "Aún no hay registros de actividad en la plataforma". |
| **Precondiciones** | El Administrador debe tener una sesión activa con los permisos de seguridad correspondientes. |
| **Postcondiciones** | El Administrador visualiza el historial completo de movimientos ordenado cronológicamente. Al ser una operación de consulta, no se realiza ninguna modificación en la base de datos. |
| **Reglas de negocio involucradas** | • La capacidad de ver este historial en la interfaz es exclusiva del actor **Administrador**.<br>• Los registros mostrados son de solo lectura y no pueden ser editados ni eliminados desde esta pantalla. |

> **Corrección aplicada:** la Postcondición original era una copia literal de la Precondición. Se sustituyó por una postcondición que describe el resultado real del caso de uso.

---

## RF-10: Exportar Reporte de Bitácora
*(sin etiqueta numérica en el original; contenido corregido)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Administrador |
| **Objetivo** | Filtrar y transformar los registros de la bitácora en un archivo digital estructurado, y descargarlo al equipo local. |
| **Flujo Principal** | 1. El Administrador, desde la vista del historial de bitácora (RF-09), hace clic en "Exportar historial".<br>2. El Sistema despliega un panel de filtros opcionales: rango de fechas (fecha inicio - fecha fin) y/o usuario específico.<br>3. El Administrador define los filtros deseados (o deja el historial sin filtrar para exportarlo completo) y selecciona el formato de salida (Excel o PDF).<br>4. El Administrador confirma haciendo clic en "Generar".<br>5. El Sistema aplica los filtros seleccionados sobre la tabla de bitácora.<br>6. El Sistema procesa la solicitud y genera el documento en el formato elegido.<br>7. El Sistema inicia la descarga del archivo en el equipo del Administrador. |
| **Puntos de Extensión** | Ninguno. |
| **Flujo Alterno** | **A. Error de generación:**<br>1. En el paso 6, el Sistema detecta un fallo al renderizar el archivo (por ejemplo, error en la librería o memoria insuficiente).<br>2. El Sistema aborta el proceso y muestra una alerta: "Error al generar el documento. Por favor, intente nuevamente".<br><br>**B. Filtros sin resultados:**<br>1. En el paso 5, el Sistema no encuentra registros de bitácora que coincidan con el rango de fechas o el usuario seleccionado.<br>2. El Sistema muestra el mensaje: "No se encontraron registros de bitácora con los filtros aplicados" y permite al Administrador ajustar los filtros o cancelar. |
| **Precondiciones** | El Administrador debe estar en la pantalla de bitácora con el historial cargado y visible (RF-09). |
| **Postcondiciones** | Un archivo físico con el reporte de auditoría, filtrado según los criterios seleccionados, es descargado y guardado en el equipo del Administrador. |
| **Reglas de negocio involucradas** | • La exportación debe permitir filtrar por **rango de fechas** y/o por **usuario específico** antes de generar el documento (RF-10).<br>• El formato de salida debe ser **Excel o PDF**, garantizando que el contenido sea idéntico en ambos formatos (RNF-24). |

> **Correcciones aplicadas:** (1) se agregó el paso de selección de filtros (fecha/usuario) y formato, que el requisito RF-10 exige explícitamente y que faltaba en el flujo original; (2) las Reglas de negocio originales eran una copia literal de la Postcondición — se sustituyeron por reglas reales; (3) se agregó el flujo alterno B (filtros sin resultados).

---

## RF-14: Registrar nuevo alumno
*(antes etiquetado como RF-09)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Administrador y Gestor Administrativo |
| **Objetivo** | Crear un expediente académico para un estudiante de nuevo ingreso, capturando sus datos personales, escolares y de seguridad, y vinculándolo al perfil de su padre o tutor correspondiente. |
| **Flujo Principal** | 1. El actor (Administrador o Gestor) ingresa al módulo de Gestión de Alumnos.<br>2. Selecciona la opción "Registrar nuevo alumno".<br>3. El sistema despliega el formulario de registro de expediente.<br>4. El actor ingresa los datos personales del alumno: nombre completo, CURP, matrícula y fecha de nacimiento.<br>5. El actor selecciona los datos académicos: nivel educativo, grado y grupo.<br>6. El actor ingresa los nombres de las personas autorizadas para recoger al alumno.<br>7. El actor asocia al alumno con el perfil de un padre o tutor (creándolo si es nuevo —ver RF-11—, o buscándolo si ya tiene otros hijos en el plantel).<br>8. El actor hace clic en "Guardar expediente".<br>9. El sistema valida que todos los datos obligatorios estén correctos.<br>10. El sistema almacena el expediente en la base de datos y muestra un mensaje de éxito ("Alumno registrado correctamente"). |
| **Flujo Alterno** | **A. Matrícula o CURP duplicada:**<br>1. En el paso 9, el sistema detecta que la matrícula o la CURP ingresada ya pertenece a otro expediente activo o inactivo.<br>2. El sistema detiene el guardado y muestra una alerta: "Error: La CURP/Matrícula ya se encuentra registrada en el sistema".<br>3. El actor verifica la información, corrige el dato erróneo y vuelve a intentar guardar.<br><br>**B. Faltan datos obligatorios:**<br>1. En el paso 9, el sistema detecta que no se asignó un tutor o no se ingresó el nivel educativo.<br>2. El sistema resalta en rojo los campos faltantes y pide al actor que los complete.<br>3. El actor llena los datos faltantes y reintenta guardar. |
| **Precondiciones** | El actor debe tener una sesión activa con rol de Administrador o Gestor Administrativo. |
| **Postcondiciones** | El sistema crea un nuevo expediente de alumno totalmente funcional y vinculado a un tutor, quedando disponible para asignación de becas, registro de calificaciones y cobro de colegiaturas. |
| **Reglas de negocio involucradas** | • La creación de expedientes está permitida tanto para el **Administrador** como para el **Gestor Administrativo**.<br>• El nivel educativo seleccionado debe pertenecer estrictamente al catálogo oficial: **preescolar, primaria, secundaria o bachillerato**.<br>• Por políticas de seguridad, es obligatorio registrar a las **personas autorizadas** y vincular forzosamente el expediente al perfil de un **padre o tutor**. |

> **Nota:** el paso 7 permite crear el perfil del tutor "sobre la marcha" si es nuevo, lo cual se solapa con RF-11 (registro de perfil de padre/tutor "de forma independiente"). Ver Notas pendientes.

---

## RF-17: Consultar expediente de alumno
*(antes etiquetado como RF-10)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Administrador y Gestor Administrativo |
| **Objetivo** | Buscar y visualizar de manera completa y detallada toda la información personal, escolar y de seguridad de un estudiante, junto con los datos de su padre o tutor vinculado. |
| **Flujo Principal** | 1. El actor (Administrador o Gestor) ingresa al módulo de Gestión de Alumnos.<br>2. Se ubica en la barra de búsqueda del directorio de alumnos.<br>3. El actor ingresa un parámetro de búsqueda (puede ser el nombre parcial o completo, la matrícula o la CURP del alumno).<br>4. El actor ejecuta la búsqueda (presionando Enter o el botón de buscar).<br>5. El sistema procesa la consulta y despliega una lista con los resultados coincidentes.<br>6. El actor selecciona el expediente deseado haciendo clic sobre él.<br>7. El sistema despliega una vista detallada que incluye todos los datos registrados del alumno y la información de contacto del tutor correspondiente. |
| **Flujo Alterno** | **A. Búsqueda sin resultados:**<br>1. En el paso 5, el sistema no encuentra ningún expediente que coincida con el nombre, matrícula o CURP ingresado.<br>2. El sistema muestra un mensaje en pantalla: "No se encontraron resultados para la búsqueda solicitada".<br>3. El actor limpia la barra de búsqueda y vuelve a intentar con un parámetro diferente (regresa al paso 3).<br><br>**B. Selección de alumno inactivo/dado de baja:**<br>1. En el paso 6, el actor selecciona el expediente de un alumno que ya no está activo en el ciclo escolar.<br>2. El sistema despliega la vista detallada, pero resalta en la cabecera el estado "INACTIVO" o "BAJA" en color rojo para evitar confusiones operativas. |
| **Precondiciones** | El actor debe tener una sesión activa con los privilegios de Administrador o Gestor Administrativo. Deben existir alumnos registrados previamente en la base de datos. |
| **Postcondiciones** | El actor visualiza la información completa del expediente. Al ser una operación de consulta, no se realiza ninguna modificación, creación ni eliminación en la base de datos. |
| **Reglas de negocio involucradas** | • La consulta completa de expedientes y datos del tutor está habilitada para los perfiles **Administrador** y **Gestor Administrativo**.<br>• El motor de búsqueda debe soportar consultas obligatoriamente por **nombre, matrícula y CURP** para facilitar la localización rápida. |

> **Nota:** este escenario es prácticamente idéntico a otro escenario de RF-17 elaborado por José Manuel Fabian Hernández. Pendiente decidir cuál conservar o cómo fusionarlos. Ver Notas pendientes.

---

## RF-18: Modificar datos de alumno o tutor
*(antes etiquetado como RF-12)*

| Campo | Descripción |
|---|---|
| **Autor** | Luis Ángel Reyes Mendoza |
| **Actor** | Administrador y Gestor Administrativo |
| **Objetivo** | Actualizar o corregir la información existente en el expediente de un estudiante o en el perfil de su padre/tutor, asegurando que el sistema cuente con datos veraces y vigentes. |
| **Flujo Principal** | 1. El actor (Administrador o Gestor) ingresa al módulo de Gestión de Alumnos.<br>2. Utiliza la barra de búsqueda para localizar al alumno por nombre o matrícula.<br>3. El actor selecciona el expediente deseado de la lista de resultados.<br>4. El actor hace clic en el botón u opción "Editar" o "Modificar datos".<br>5. El sistema habilita los campos del formulario con la información actual precargada.<br>6. El actor ingresa la información corregida o actualizada (ya sea del alumno o de su tutor vinculado).<br>7. El actor hace clic en "Guardar cambios".<br>8. El sistema valida que los nuevos datos introducidos sean correctos y que no falte información obligatoria.<br>9. El sistema actualiza la base de datos de forma inmediata y muestra un mensaje de confirmación: "Datos actualizados correctamente". |
| **Flujo Alterno** | **A. Cancelación de la edición:**<br>1. En el paso 6, el actor decide no aplicar ninguna actualización y hace clic en el botón "Cancelar".<br>2. El sistema descarta los cambios en pantalla y devuelve al actor a la vista detallada del expediente original sin alterar la base de datos.<br><br>**B. Dato obligatorio eliminado o inválido:**<br>1. En el paso 8, el sistema detecta que el actor borró accidentalmente un campo obligatorio (como la CURP) o ingresó un formato inválido.<br>2. El sistema detiene la actualización, resalta el campo erróneo en rojo y muestra una alerta: "Por favor, complete correctamente los campos obligatorios".<br>3. El actor corrige el dato y vuelve a intentar guardar. |
| **Precondiciones** | El actor debe tener sesión activa con los permisos adecuados. El expediente del alumno o perfil del tutor debe existir previamente en el sistema. |
| **Postcondiciones** | La base de datos queda actualizada con la nueva información. Dado que es un sistema integrado, los datos modificados (ej. cambio de grado del alumno o nombre del tutor) se reflejan inmediatamente en los demás módulos (como facturación o calificaciones). |
| **Reglas de negocio involucradas** | *(no definidas en el documento original — pendiente)* |

> **Nota:** este escenario cubre tanto datos del alumno (RF-18) como datos del tutor (RF-13), y se solapa con dos escenarios de José Manuel Fabian Hernández dedicados específicamente a cada uno. Pendiente decidir si se elimina, se acota solo a RF-18, o se fusiona. Ver Notas pendientes.

---

## Notas pendientes

Estos puntos quedaron identificados durante la corrección, pero requieren una decisión antes de cerrar el documento definitivo:

1. **RF-06 (Cerrar sesión):** se ajustó terminología web ("token", "navegador") a un lenguaje más neutro/desktop. Si el equipo decide que parte del sistema sí tendrá un componente web (recordando la duda pendiente sobre el portal de padres), esta redacción podría revisarse de nuevo más adelante.
2. **RF-14 (Registrar nuevo alumno):** el paso 7 permite crear el perfil del tutor "sobre la marcha". Definir si esto es un punto de extensión formal hacia RF-11, o si se elimina esa opción y se obliga a registrar primero al tutor por RF-11.
3. **RF-17 (Consultar expediente de alumno):** escenario duplicado con el de José Manuel Fabian Hernández. Decidir cuál conservar o cómo fusionarlos.
4. **RF-18 (Modificar datos de alumno o tutor):** se solapa con RF-13 y con otro escenario de RF-18 de José Manuel. Decidir si se elimina, se acota o se fusiona. Además, le falta la sección "Reglas de negocio involucradas".
