-- Fila de eventos do agente de WhatsApp para o CRM Núcleo.
-- Rode uma vez no Postgres usado pelo n8n (pode ser o do Supabase).
CREATE TABLE IF NOT EXISTS nucleo_eventos (
  seq       BIGSERIAL PRIMARY KEY,           -- número crescente: o CRM pede "desde" este número
  id        TEXT UNIQUE NOT NULL,            -- id único do evento (evita duplicidade)
  tipo      TEXT NOT NULL,                   -- contato | interacao | negocio | etapa | tarefa
  dados     JSONB NOT NULL DEFAULT '{}'::jsonb,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Opcional: limpar eventos com mais de 30 dias (agende no n8n se quiser).
-- DELETE FROM nucleo_eventos WHERE criado_em < now() - interval '30 days';
