-- Andalucía 2026 · migración 0002
-- Tabla de gastos comunes para la pestaña 💶 Gastos.
-- El hospedaje va aparte (tabla alojamientos): aquí van la van, las visitas,
-- la gasolina, los peajes y cualquier cosa que ponga uno y se reparta entre todos.

create table if not exists public.gastos (
  id           text primary key,
  concepto     text not null default '',
  categoria    text not null default 'otro',   -- carro | actividad | comida | otro
  importe      numeric not null default 0,
  moneda       text not null default 'EUR',    -- EUR | USD
  fecha        date,
  pagado_por   text not null default 'A',      -- núcleo que puso el dinero: A | B | K
  sin_elina    boolean not null default false, -- para gastos de adultos (catas, entradas)
  notas        text default '',
  created_at   timestamptz not null default now()
);

create index if not exists gastos_categoria_idx on public.gastos (categoria);

-- Misma política que alojamientos: web pública y sin login.
alter table public.gastos enable row level security;

drop policy if exists "gastos_anon_all" on public.gastos;
create policy "gastos_anon_all" on public.gastos
  for all to anon using (true) with check (true);

-- Sync en vivo entre los dispositivos de la familia.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='gastos'
  ) then
    alter publication supabase_realtime add table public.gastos;
  end if;
end $$;

-- Primer gasto: la van, ya pagada por Johan (núcleo A).
-- Idempotente: si vuelves a correr la migración no se duplica.
insert into public.gastos (id, concepto, categoria, importe, moneda, fecha, pagado_por, sin_elina, notas)
values (
  'van-barajas-2026',
  'Van 9 plazas · 13 días',
  'carro',
  945.01,
  'EUR',
  '2026-09-10',
  'A',
  false,
  'Prepago con Full Coverage: 72,69 €/día × 13 días. Recogida y devolución en Barajas, 2 oct 15:00 → 15 oct 15:00. APARTE quedan el depósito en tarjeta de crédito al recoger (reembolsable) y el diésel.'
)
on conflict (id) do nothing;
