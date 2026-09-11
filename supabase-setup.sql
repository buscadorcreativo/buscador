-- ═══════════════════════════════════════════════════════════
-- RADAR CREATIVO COLOMBIA — Supabase Setup
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query
--
-- El script se puede correr varias veces sin romperse.
-- Después de correrlo: Settings → API → copiar Project URL y anon public key,
-- y reemplazarlas en index.html (bloque CONFIG, arriba del <script>).
-- ═══════════════════════════════════════════════════════════

-- ── Postulaciones: el seguimiento de convocatorias ──
CREATE TABLE IF NOT EXISTS postulaciones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  entity TEXT DEFAULT '',
  type TEXT CHECK (type IN ('secop','publica','privada','internacional','otro')) DEFAULT 'otro',
  status TEXT CHECK (status IN ('interesado','preparando','enviada','aceptada','rechazada')) DEFAULT 'interesado',
  url TEXT DEFAULT '',
  value TEXT DEFAULT '',
  deadline TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Perfil: una sola fila (id = 1) ──
-- Es lo que hace que el perfil te siga entre el computador y el celular.
CREATE TABLE IF NOT EXISTS perfil (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  nombre TEXT DEFAULT 'Bushido',
  tipo TEXT DEFAULT 'juridica',
  disciplinas TEXT DEFAULT '',
  ciudad TEXT DEFAULT 'Bogotá / Cali',
  experiencia TEXT DEFAULT '5+',
  rup TEXT DEFAULT 'no',
  activos NUMERIC DEFAULT 0,
  pasivos NUMERIC DEFAULT 0,
  activo_corriente NUMERIC DEFAULT 0,
  pasivo_corriente NUMERIC DEFAULT 0,
  utilidad_operacional NUMERIC DEFAULT 0,
  gastos_intereses NUMERIC DEFAULT 0,
  experiencia_detalle TEXT DEFAULT '',
  documentos TEXT[] DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Columnas nuevas para una base que ya existía de antes
ALTER TABLE perfil ADD COLUMN IF NOT EXISTS utilidad_operacional NUMERIC DEFAULT 0;
ALTER TABLE perfil ADD COLUMN IF NOT EXISTS gastos_intereses NUMERIC DEFAULT 0;

-- La fila única del perfil. Los datos los llena la app; acá solo se reserva el renglón.
INSERT INTO perfil (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- ── Barridos: bitácora del agente de monitoreo ──
CREATE TABLE IF NOT EXISTS barridos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  fecha TIMESTAMPTZ DEFAULT NOW(),
  nuevas_encontradas INTEGER DEFAULT 0,
  resumen TEXT DEFAULT ''
);

-- NOTA: aquí había una tabla "convocatorias". Se quitó a propósito.
-- Las convocatorias culturales viven en convocatorias.json dentro del repo, que es
-- la única fuente de verdad y de donde las lee la app. Tener además una tabla en
-- Supabase reviviría el problema que ya tuvimos: dos bases desincronizadas donde
-- lo que encontraba el agente nunca llegaba a la pantalla.

-- ── RLS: acceso anónimo (app personal de un solo usuario, sin login) ──
ALTER TABLE postulaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE perfil        ENABLE ROW LEVEL SECURITY;
ALTER TABLE barridos      ENABLE ROW LEVEL SECURITY;

-- Se borran antes de crear para que el script se pueda repetir sin error.
DROP POLICY IF EXISTS "anon_all" ON postulaciones;
DROP POLICY IF EXISTS "anon_all" ON perfil;
DROP POLICY IF EXISTS "anon_all" ON barridos;

CREATE POLICY "anon_all" ON postulaciones FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "anon_all" ON perfil        FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "anon_all" ON barridos      FOR ALL USING (true) WITH CHECK (true);

-- ⚠ La anon key queda visible en el código del navegador y estas políticas dejan
-- leer y escribir a cualquiera que tenga la URL del proyecto. Es aceptable para
-- postulaciones y perfil de una sola persona. NO guardes aquí la API key de Claude
-- ni nada que no puedas permitirte que sea público: esa key se queda en el
-- navegador de cada equipo, a propósito.
