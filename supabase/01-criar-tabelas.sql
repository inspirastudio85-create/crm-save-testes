-- Núcleo CRM/ERP — tabelas no Supabase
-- Cole tudo no SQL Editor do Supabase e clique em "Run". Pode rodar de novo sem problema.

-- 1) Todos os dados do sistema (contatos, negócios, vendas, estoque, financeiro...)
create table if not exists public.nucleo_registros (
  colecao       text        not null,               -- contacts, deals, tasks, products, moves, orders, purchases, fin, cfg
  id            text        not null,
  dados         jsonb       not null default '{}'::jsonb,
  upd           bigint      not null default 0,      -- quando foi alterado (o mais novo vence)
  excluido      boolean     not null default false,
  atualizado_em timestamptz not null default now(),
  primary key (colecao, id)
);
create index if not exists nucleo_registros_atualizado on public.nucleo_registros (atualizado_em);

-- Uma alteração mais antiga nunca sobrescreve uma mais nova
create or replace function public.nucleo_mais_novo_vence() returns trigger
language plpgsql as $$
begin
  if new.upd < old.upd then return null; end if;
  new.atualizado_em := now();
  return new;
end $$;
drop trigger if exists nucleo_registros_lww on public.nucleo_registros;
create trigger nucleo_registros_lww before update on public.nucleo_registros
  for each row execute function public.nucleo_mais_novo_vence();

-- 2) Eventos que o agente de WhatsApp (n8n) manda para o CRM
create table if not exists public.nucleo_eventos (
  seq           bigserial   primary key,
  id            text        unique not null,         -- id único do evento (evita duplicar)
  tipo          text        not null,
  dados         jsonb       not null default '{}'::jsonb,
  criado_em     timestamptz not null default now()
);
alter table public.nucleo_eventos add column if not exists processado_em timestamptz;
alter table public.nucleo_eventos add column if not exists ok boolean;
alter table public.nucleo_eventos add column if not exists resultado text;
-- O agente só alimenta o CRM: qualquer outro tipo é recusado pelo próprio banco
alter table public.nucleo_eventos drop constraint if exists nucleo_eventos_tipo_ok;
alter table public.nucleo_eventos add constraint nucleo_eventos_tipo_ok
  check (tipo in ('contato','interacao','negocio','etapa','tarefa'));
create index if not exists nucleo_eventos_pendentes on public.nucleo_eventos (seq) where processado_em is null;

-- 3) Acesso pelo navegador (o sistema não tem login, então a chave publicável/anon tem acesso total
--    a ESTAS duas tabelas. Não compartilhe a URL + chave com quem não deve ver seus dados.)
alter table public.nucleo_registros enable row level security;
alter table public.nucleo_eventos   enable row level security;
drop policy if exists nucleo_registros_tudo on public.nucleo_registros;
create policy nucleo_registros_tudo on public.nucleo_registros for all to anon, authenticated using (true) with check (true);
drop policy if exists nucleo_eventos_tudo on public.nucleo_eventos;
create policy nucleo_eventos_tudo on public.nucleo_eventos for all to anon, authenticated using (true) with check (true);
grant select, insert, update, delete on public.nucleo_registros, public.nucleo_eventos to anon, authenticated;
grant usage, select on sequence public.nucleo_eventos_seq_seq to anon, authenticated;

-- 4) Tempo real: avisa o CRM na hora quando algo muda
do $$ begin
  alter publication supabase_realtime add table public.nucleo_registros;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.nucleo_eventos;
exception when duplicate_object then null; end $$;

-- Opcional: apagar eventos já processados com mais de 30 dias
-- delete from public.nucleo_eventos where processado_em < now() - interval '30 days';
