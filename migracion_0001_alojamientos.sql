-- Andalucía 2026 · migración 0001
-- Tabla de alojamientos para las pestañas 🏠 Casas y 📊 Hospedaje.
-- Equivale al esquema final de Sicilia (migraciones 0001+0002+0003+0004+0005 juntas).

create table if not exists public.alojamientos (
  id            text primary key,
  base          text not null,
  nombre        text not null default '',
  url           text default '',
  precio        numeric,
  habitaciones  numeric,
  banos         numeric,
  capacidad     numeric,
  parqueo       boolean not null default false,
  rating        numeric,
  notas         text default '',
  foto          text,
  extras        jsonb not null default '[]'::jsonb,
  reservada     boolean not null default false,
  invite        text,
  elegida       boolean not null default false,
  created_at    timestamptz not null default now()
);

create index if not exists alojamientos_base_idx on public.alojamientos (base);

-- La web es pública y sin login (igual que Sicilia): acceso anónimo permisivo.
alter table public.alojamientos enable row level security;

drop policy if exists "alojamientos_anon_all" on public.alojamientos;
create policy "alojamientos_anon_all" on public.alojamientos
  for all to anon using (true) with check (true);

-- Sync en vivo entre los dispositivos de la familia.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='alojamientos'
  ) then
    alter publication supabase_realtime add table public.alojamientos;
  end if;
end $$;
