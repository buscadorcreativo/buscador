# AUDITORÍA Y TRASPASO — Radar Creativo Colombia 2026

> **Para:** El chat / desarrollador que reciba este proyecto
> **De:** Maick (Bushido, productora audiovisual · Bogotá / Cali)
> **Objetivo del documento:** que puedas auditar el estado real del sistema, entender qué funciona, qué no, y qué falta para dejarlo operativo y con monitoreo actualizable — sin tener que re-explicar el contexto.
> **Fecha del traspaso:** actualízala al momento de entregar.

---

## 0. Léeme primero (contexto en 60 segundos)

Es una **app web de un solo archivo HTML** (~104 KB, ~1.470 líneas, sin dependencias ni build) para ayudar a creativos colombianos (audiovisual, foto, diseño, artes visuales) a **encontrar convocatorias y licitaciones y evaluar si son aptos para postularse**.

Tiene 6 pestañas: un buscador del **SECOP II en vivo** (contratación pública, vía API), cuatro pestañas de **convocatorias culturales curadas a mano**, y un **analizador con IA** (Claude API) que evalúa una convocatoria y dice si el usuario es apto y qué le falta.

Está en **fase de validación con un solo usuario (Bushido)** antes de decidir si se construye un backend. **No hay servidor.** Todo corre en el navegador; los datos del usuario viven en `localStorage`.

**El dolor #1 hoy** — y la razón principal de esta auditoría: **las convocatorias culturales están escritas a mano en el código y se vencen.** Cuando pasan de fecha, se quedan ahí muertas hasta que alguien edita el HTML. Hay que arreglar esa arquitectura. Ver §5 y §7.

---

## 1. Qué es cada pestaña y en qué estado está

| Pestaña | Qué hace | Fuente de datos | Estado |
|---|---|---|---|
| 🔎 **SECOP II** | Busca procesos de contratación pública en vivo, con filtros | **API en vivo** (datos.gov.co) | ✅ Funciona. Se actualiza solo. |
| 🏛 **Públicas** | Convocatorias culturales públicas (IDARTES, FDC, SINAC, FUGA…) | **Hardcoded** (array `PUB`) | ⚠️ Funciona pero se vence. |
| 🏢 **Privadas** | Convocatorias privadas (SmartFilms, Bacánika, Comfama…) | **Hardcoded** (array `PRIV`) | ⚠️ Funciona pero se vence. |
| 🌎 **Internacional** | Fondos internacionales (Ibermedia, Hubert Bals, Sundance…) | **Hardcoded** (array `INTER`) | ⚠️ Funciona pero se vence. |
| 📡 **Fuentes Radar** | Lista de portales oficiales para monitorear manualmente | **Hardcoded** (array `FUENTES`) | ✅ Estable (los portales no se vencen). |
| 🧠 **Analizador IA** | Pega texto de una convocatoria → análisis de aptitud + propuestas | **Claude API** (key del usuario) | ✅ Funciona con API key. |

**La clave que tienes que entender:** la parte que se actualiza sola (SECOP) es la que NO tocamos a mano. La parte que curamos a mano (culturales) es la que se pudre. Es la peor combinación y es lo que hay que corregir.

---

## 2. Arquitectura técnica actual

- **Un solo archivo:** `radar-creativo-colombia-v6.html`. HTML + CSS + JS inline. Sin frameworks, sin build, sin `npm`. Se abre con doble clic o servido estático.
- **Persistencia:** `localStorage` del navegador. Un solo usuario, un solo dispositivo. Claves con prefijo `rc_` (ej. `rc_key`, `rc_p_pn`, `rc_p_docs`, `rc_configurado`).
- **Sin backend, sin cuentas, sin login.**
- **Diseño:** dark mode, fuentes Space Mono + Barlow Condensed, amarillo `#f0e040`. Estética "radar/terminal".

### Fuente SECOP II (la parte viva)
- Dataset Socrata: `https://www.datos.gov.co/resource/p6dx-8zbt.json`
  ("SECOP II - Procesos de Contratación", de Colombia Compra Eficiente). **Confirmado activo en 2026.**
- Como el dataset no permite CORS directo desde el navegador, se usa una **cascada de 5 proxies CORS** con failover automático y timeout de 12s (`fetchConProxies()`): directo → corsproxy.io → codetabs → allorigins → corsfix. Muestra "Conectando vía [proxy]".
- Query con SoQL: `$q`, `$where`, `$order`, `$limit`, `$offset`. Se construye en `buildWhere()`, `buildOrder()`, `rawDataURL()`, `rawCountURL()`.

### Analizador IA
- Llama a la **Claude API** (`https://api.anthropic.com/v1/messages`) directo desde el navegador con la API key que el usuario pega y se guarda en `localStorage`.
- Prompt en `buildPrompt()` → pide un JSON estructurado (resumen, requisitos, **aptitud**, viabilidad, 3 propuestas, alertas, pasos).
- Costo aproximado: ~USD 0,01 por análisis.

---

## 3. Mapa de funciones (para orientarte en el código)

**SECOP / búsqueda:**
`buscar()` (orquesta), `rawDataURL()`, `rawCountURL()`, `buildWhere()`, `buildOrder()`, `cuantiaWhere()`, `fechaDesde()`, `fetchConProxies()`, `rCards()`, `mkCard()`, `extraerUrl()` (defensiva), `rPag()`, `showErr()`, `tSort()`.

**Perfil + aptitud:**
`precargarBushido()` (pre-carga perfil la 1ª vez), `getPerfil()` (arma perfil + calcula índices financieros), `toggleLicit()`, `num()`, chips de documentos.

**Analizador IA:**
`buildPrompt()`, `callClaude()`, `analizarDirecto()`, `analizarDesdeModal()`, `abrirModal()`, `renderAnaResults()` y las `mk*H()` que renderizan cada bloque (`mkAptitudH`, `mkChecklistH`, `mkViaH`, `mkPropsH`, `mkResumenH`, `mkAlertasH`, `mkPasosH`).

**Culturales (hardcoded):**
`renderPub()`, `renderGrid()`, `renderFuentes()`, `mkCC()` (arma cada tarjeta), `ff()` (filtro por categoría). Arrays: `PUB`, `PRIV`, `INTER`, `FUENTES`.

**Utilidades:** `esc()` (escapa HTML), `fD()` (formatea fecha), `fV()` (formatea valor $), `sw()` (cambia pestañas), `tick()` (reloj).

---

## 4. Filtros del SECOP (estado actual)

Todos implementados en `buildWhere()` y el orden en `buildOrder()`:

- **Estado** (`sest`): "Todos" (default seguro), "Solo abiertos", "Adjudicado", "Desierto".
  Usa **`LIKE` flexible con `upper()`** (no igualdad exacta), buscando varias formas: `PRESENTACI%`, `CONVOCAD%`, `PUBLICAD%`, `ABIERTO%`.
- **Período** (`speriodo`): "Todo 2026", "Últimos 3 meses" (default, más activos), "Último mes", "Últimos 15 días". Lógica en `fechaDesde()`.
- **Modalidad** (`smodalidad`): las 5 oficiales (Ley 1150) — Mínima cuantía, Licitación pública, Selección abreviada, Concurso de méritos, Contratación directa. `LIKE upper()`.
- **Cuantía** (`scuantia`): ≤$132M / $132M–$1.000M / >$1.000M. Lógica en `cuantiaWhere()`.
- **Departamento** (`sdepto`): busca en `departamento_entidad` OR `ciudad_entidad` con `LIKE upper()`.
- **Orden:** fecha reciente/antigua, valor menor/mayor. Vars `ordenCampo` / `ordenDir`.

> ⚠️ **Punto a verificar en auditoría (ver §6):** el filtro "Solo abiertos" depende de que los textos que asumí (`PRESENTACI`, `CONVOCAD`…) coincidan con los valores reales del campo `estado_del_procedimiento`. No se pudo probar contra la API en vivo (ver §8). **Hay que confirmar los valores reales y ajustar.**

---

## 5. El perfil de aptitud (lo más valioso funcionalmente)

En la pestaña Analizador hay una sección desplegable **"Perfil para licitaciones públicas"** donde el usuario carga una vez:

- **Capacidad financiera:** activos, pasivos, activo corriente, pasivo corriente. `getPerfil()` calcula solos los **índices** que pide el SECOP: liquidez, endeudamiento, capital de trabajo.
- **Experiencia certificada** (texto libre).
- **Documentos que ya tiene** (chips marcables): RUT, Cámara de Comercio, RUP, estados financieros, certificados de experiencia, antecedentes, pólizas, certificación bancaria, seguridad social, HV del equipo.

Cuando el usuario analiza una convocatoria, el informe incluye un bloque **"¿Soy apto?"** que combina: veredicto (APTO / PARCIAL / NO APTO), documentos que tiene y sirven, documentos que faltan (marcando críticos + cómo conseguirlos), análisis financiero comparando sus índices contra lo típico del proceso, match de experiencia, y tiempo estimado para alistar lo que falta.

**Perfil de Bushido pre-cargado** (`PERFIL_BUSHIDO` + `precargarBushido()`): se llena solo la primera vez, respeta cambios posteriores (flag `rc_configurado`). Faltan los **números financieros reales** (son privados; el usuario los llena).

**Documentos reales para licitar (verificado con Colombia Compra Eficiente)** — 4 categorías de requisitos habilitantes:
1. **Jurídica:** cédula/cert. representación legal, RUT, RUP, antecedentes.
2. **Financiera:** estados financieros a 31-dic del año anterior, índices de liquidez y endeudamiento.
3. **Organizacional:** rentabilidad.
4. **Experiencia:** certificados de contratos similares + códigos UNSPSC.
> Dato clave: el SECOP II ya consulta el RUP y el cert. de representación legal **automáticamente** vía Directorio SECOP. El sistema debe enfocarse en lo que el SECOP NO valida solo: experiencia, capacidad financiera vs. pliego, y documentos puntuales.

---

## 6. Bugs ya resueltos (historial, para que no los rompas)

- **CORS:** allorigins caía seguido → se reemplazó por cascada de 5 proxies con failover.
- **Links del SECOP daban página de error:** se usaba la referencia humana (`MC-19-2026`) en `OpportunityDetail/Index`, que espera un ID interno (`CO1.REQ…`). Corregido con `extraerUrl()`: usa el campo `urlproceso` (que puede venir **string U objeto** `{url, description}` — Socrata), si no el ID interno con `noticeUID`, y como último recurso manda al buscador público. Botón "⧉ Ref" copia la referencia.
- **`urlProceso.startsWith is not a function`:** el campo venía como objeto y se trató como string. Resuelto en `extraerUrl()` + `try/catch` por tarjeta en `rCards()` (una tarjeta mala ya no tumba la página) + `showErr()` que distingue error de red vs. error de datos.
- **Filtro "Solo abiertos" no devolvía nada:** usaba igualdad exacta con un valor ("Convocado") que el dataset no usa tal cual. Migrado a `LIKE upper()` flexible. **PENDIENTE confirmar valores reales (ver §4 y §8).**

---

## 7. Lo que FALTA para que funcione bien — priorizado

### 🔴 Prioridad 1 — Convocatorias culturales actualizables (el dolor #1)
**Problema:** los arrays `PUB`, `PRIV`, `INTER` están hardcoded. Se vencen y se quedan pegados. Actualizar hoy = editar el HTML.
**Solución propuesta (sin backend, gratis):** mover esas convocatorias a un **Google Sheet** publicado como CSV. La app hace `fetch` del CSV y arma las tarjetas en runtime. Al vencerse una, se edita/borra una fila y la app se actualiza sola. La hoja puede ocultar automáticamente las vencidas comparando `fechaCierre` con hoy.
**Modelo de datos sugerido (columnas):** `icon, title, org, cat, desc, tags, val, estado, fechaCierre (YYYY-MM-DD), url`.
**Ojo, honestidad:** esto **no elimina la curación manual** — no existe API de convocatorias culturales en Colombia. Solo mueve el trabajo del código a una hoja (30 seg/fila). *Encontrar* las convocatorias sigue siendo humano — y ese trabajo de curación ES el servicio que se podría cobrar después.

### 🟠 Prioridad 2 — Confirmar el filtro de estado del SECOP
Verificar los valores reales de `estado_del_procedimiento` contra la API en vivo y ajustar el `LIKE` de "Solo abiertos". (No se pudo probar desde el entorno de desarrollo — ver §8.)

### 🟡 Prioridad 3 — Robot de monitoreo automático (el "puente gratis")
Un **Google Apps Script** con trigger diario que: consulta el SECOP (o revisa fuentes), detecta procesos nuevos que matcheen los intereses del usuario, y manda un **correo de alerta**. Es el paso intermedio hacia notificaciones automáticas **sin montar servidor**. (Apps Script sí puede llamar APIs externas sin problema de CORS.)

### 🟢 Prioridad 4 (fase 2, solo si la validación con Bushido funciona) — Backend real
Necesario para: multiusuario con login, documentos guardados en la nube, intereses por sector persistentes, notificaciones push/WhatsApp automáticas, robot server-side. Stack sugerido coherente con lo que Maick ya usa: **Next.js + Supabase + Vercel** (RLS para aislar usuarios). El modelo de datos del Google Sheet migra casi directo.

---

## 8. Limitaciones del entorno de desarrollo (importante para auditar)

- **No se puede probar la API del SECOP desde el entorno donde se construyó** (datos.gov.co no está en la allowlist de red del sandbox). Toda la lógica de query se validó **sintácticamente** (extrayendo el JS y corriendo `new Function()` con Node), pero **no contra datos reales**. Las pruebas en vivo las hace Maick en su navegador. → Por eso §7 P2 queda pendiente de confirmación.
- **No se puede automatizar la *presentación* de propuestas al SECOP:** requiere firma digital personal del representante legal. Automatizar eso sería ilegal. El sistema ayuda a *encontrar, analizar y preparar* — no a *radicar*.
- **Las fuentes culturales no tienen API.** URLs cambian seguido; requieren verificación humana periódica.
- **`localStorage` = 1 usuario / 1 navegador.** No es multiusuario.

---

## 9. Cómo probar que funciona (checklist de QA)

1. Abrir el HTML en un navegador (idealmente servido, no `file://`).
2. **SECOP:** pestaña 🔎 → "Buscar". Debe traer resultados con "Todos los estados". Probar filtros (3 meses, modalidad, departamento, orden). Cambiar a "Solo abiertos" y confirmar si trae resultados (§7 P2).
3. **Link:** en una tarjeta, "Ver proceso" / "Buscar en SECOP" no debe caer en página de error. "⧉ Ref" copia la referencia.
4. **Culturales:** pestañas 🏛🏢🌎 renderizan tarjetas; filtros por categoría funcionan.
5. **Analizador:** pegar API key de Claude (empieza con `sk-ant-`), pegar texto de una convocatoria, "Analizar". Debe devolver resumen + aptitud + 3 propuestas.
6. **Aptitud:** llenar "Perfil para licitaciones" con números → re-analizar → el bloque "¿Soy apto?" debe comparar contra esos números.
7. **Persistencia:** recargar la página; el perfil y la API key deben seguir ahí.

---

## 10. Preguntas abiertas para el que audite

1. ¿Migramos las convocatorias culturales a Google Sheet ya, o se mantiene hardcoded una iteración más mientras Maick valida?
2. ¿Confirmamos los valores reales de `estado_del_procedimiento` y cerramos el filtro "Solo abiertos"?
3. ¿Vale la pena el robot de Apps Script durante la validación, o se espera al backend?
4. Para Bushido específicamente: gran parte de su oportunidad real está en **convocatorias culturales** (FDC, IDARTES, SmartFilms), no tanto en el SECOP de contratación tradicional. ¿El producto debería inclinarse más hacia curar bien lo cultural que hacia el SECOP? (Dato de producto, no solo técnico.)

---

## 11. Archivos del proyecto

- `radar-creativo-colombia-v6.html` — **la app. Único archivo que importa.**
- `plan-negocio-servicio-curado.md` — modelo de negocio (servicio curado hecho-para-ti).
- `analisis-radar-hoja-de-ruta.md` — análisis crítico del SECOP y qué es viable automatizar.
- *(este)* `AUDITORIA-radar-creativo.md` — traspaso y auditoría.

---

*Nota de tono para el chat receptor: Maick prefiere honestidad directa sobre complacencia. Si algo de esta arquitectura está mal pensado, dilo y propón mejor. No infles lo que funciona ni escondas lo que falta.*
