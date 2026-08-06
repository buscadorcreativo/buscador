-- ═══════════════════════════════════════════════════════════
-- RADAR CREATIVO COLOMBIA — Supabase Setup
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query
-- ═══════════════════════════════════════════════════════════

-- Postulaciones: seguimiento de convocatorias del usuario
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

-- Convocatorias conocidas: base de datos del agente de monitoreo
CREATE TABLE IF NOT EXISTS convocatorias (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  fuente TEXT NOT NULL,
  titulo TEXT NOT NULL,
  estado TEXT DEFAULT 'abierto',
  cierre DATE,
  url TEXT DEFAULT '',
  valor TEXT DEFAULT '',
  disciplinas TEXT[] DEFAULT '{}',
  quien_aplica TEXT DEFAULT '',
  viable_bushido BOOLEAN,
  notas TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(fuente, titulo)
);

-- Perfil del usuario
CREATE TABLE IF NOT EXISTS perfil (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  nombre TEXT DEFAULT 'Bushido',
  tipo TEXT DEFAULT 'juridica',
  disciplinas TEXT DEFAULT 'producción audiovisual, edición de video, fotografía, podcast documental',
  ciudad TEXT DEFAULT 'Bogotá / Cali',
  experiencia TEXT DEFAULT '5+',
  rup TEXT DEFAULT 'no',
  activos NUMERIC DEFAULT 0,
  pasivos NUMERIC DEFAULT 0,
  activo_corriente NUMERIC DEFAULT 0,
  pasivo_corriente NUMERIC DEFAULT 0,
  experiencia_detalle TEXT DEFAULT '',
  documentos TEXT[] DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insertar perfil Bushido por defecto
INSERT INTO perfil (nombre, tipo, disciplinas, ciudad, experiencia, rup, experiencia_detalle)
VALUES (
  'Bushido',
  'juridica',
  'producción audiovisual, edición de video, fotografía, podcast documental, cobertura de eventos',
  'Bogotá / Cali',
  '5+',
  'no',
  'Producción y cobertura audiovisual para marcas: Cinemark, cubrimiento de conciertos de J Balvin, HYPE SAS, Robusta SAS. Edición de video, fotografía profesional y podcast documental.'
) ON CONFLICT (id) DO NOTHING;

-- Último barrido del agente
CREATE TABLE IF NOT EXISTS barridos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  fecha TIMESTAMPTZ DEFAULT NOW(),
  nuevas_encontradas INTEGER DEFAULT 0,
  resumen TEXT DEFAULT ''
);

-- RLS: acceso anónimo (app personal, sin auth)
ALTER TABLE postulaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE convocatorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE perfil ENABLE ROW LEVEL SECURITY;
ALTER TABLE barridos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_all" ON postulaciones FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "anon_all" ON convocatorias FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "anon_all" ON perfil FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "anon_all" ON barridos FOR ALL USING (true) WITH CHECK (true);
