-- Andalucía 2026 · migración 0004
-- La pestaña 🎟️ Reservas: el checklist de todo lo que hay que reservar o comprar,
-- y los comprobantes de lo ya cerrado (vouchers, entradas, tarjetas de embarque).
--
-- SEGURIDAD. Aquí dentro van documentos con nombre y número de pasaporte, y el
-- localizador del vuelo. Por eso TODAS las políticas de este fichero son
-- 'to authenticated', nunca 'to anon': aunque la migración 0003 no estuviera
-- corrida todavía, estos archivos no son accesibles sin sesión iniciada.
-- El bucket va PRIVADO: solo se sirve con URL firmada.
--
-- Correr DESPUÉS de la 0003.

-- ============================================================
-- 1. Las reservas
-- ============================================================
create table if not exists public.reservas (
  id           text primary key,
  titulo       text not null default '',
  tipo         text not null default 'otro',      -- vuelo | van | casa | entrada | actividad | documento | otro
  estado       text not null default 'pendiente', -- pendiente | reservado | comprado | sin-reserva
  dia          date,                              -- día del viaje al que aplica
  hora         text default '',
  limite       date,                              -- fecha tope para reservarlo
  proveedor    text default '',
  localizador  text default '',                   -- nº de reserva, PNR, código
  url          text default '',                   -- dónde se compra o se gestiona
  importe      numeric,
  moneda       text not null default 'EUR',
  notas        text default '',
  orden        numeric not null default 0,
  created_at   timestamptz not null default now()
);
create index if not exists reservas_estado_idx on public.reservas (estado);
create index if not exists reservas_dia_idx    on public.reservas (dia);

-- ============================================================
-- 2. Los archivos de cada reserva
--    'ruta' es la clave dentro del bucket. 'etiqueta' permite tener una
--    entrada por persona: "Elina", "Abuela Pili"...
-- ============================================================
create table if not exists public.reserva_archivos (
  id          text primary key,
  reserva_id  text not null references public.reservas(id) on delete cascade,
  ruta        text not null,
  nombre      text not null default '',
  etiqueta    text default '',
  tipo        text default '',
  tam         numeric,
  created_at  timestamptz not null default now()
);
create index if not exists reserva_archivos_res_idx on public.reserva_archivos (reserva_id);

-- ============================================================
-- 3. Permisos: SOLO con sesión iniciada
-- ============================================================
alter table public.reservas         enable row level security;
alter table public.reserva_archivos enable row level security;

drop policy if exists "reservas_auth" on public.reservas;
create policy "reservas_auth" on public.reservas
  for all to authenticated using (true) with check (true);

drop policy if exists "reserva_archivos_auth" on public.reserva_archivos;
create policy "reserva_archivos_auth" on public.reserva_archivos
  for all to authenticated using (true) with check (true);

-- ============================================================
-- 4. El bucket de archivos
--    file_size_limit va en BYTES cuando se crea por SQL. Poner 15 en vez de
--    15728640 deja un límite de 15 bytes y todas las subidas rebotan con 413.
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'comprobantes', 'comprobantes',
  false,          -- privado: sin URL firmada no se sirve nada
  15728640,       -- 15 MB por archivo
  array[
    'application/pdf',
    'image/jpeg','image/png','image/webp','image/heic','image/heif',
    'application/vnd.apple.pkpass',
    'application/octet-stream'   -- iOS a veces no manda tipo
  ]
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- RLS ya viene activado de fábrica en storage.objects: no hay que tocarlo.
-- Los permisos se filtran por bucket_id. Todo a 'authenticated'.
drop policy if exists "comprobantes_auth_ins" on storage.objects;
create policy "comprobantes_auth_ins" on storage.objects
  for insert to authenticated with check ( bucket_id = 'comprobantes' );

-- Este SELECT es el que permite firmar URLs (createSignedUrl) y descargar.
drop policy if exists "comprobantes_auth_sel" on storage.objects;
create policy "comprobantes_auth_sel" on storage.objects
  for select to authenticated using ( bucket_id = 'comprobantes' );

drop policy if exists "comprobantes_auth_del" on storage.objects;
create policy "comprobantes_auth_del" on storage.objects
  for delete to authenticated using ( bucket_id = 'comprobantes' );

-- ============================================================
-- 5. Sync en vivo
-- ============================================================
do $$
begin
  if not exists (select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='reservas') then
    alter publication supabase_realtime add table public.reservas;
  end if;
  if not exists (select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='reserva_archivos') then
    alter publication supabase_realtime add table public.reserva_archivos;
  end if;
end $$;

-- ============================================================
-- 6. El checklist, sembrado. Idempotente por id.
-- ============================================================
insert into public.reservas (id,titulo,tipo,estado,dia,hora,limite,proveedor,localizador,url,importe,moneda,notas,orden) values
('vuelo-mad-ory','Vuelo Madrid → París-Orly · TO 4639','vuelo','comprado','2026-10-15','18:30',null,'Transavia France','','https://www.transavia.com',null,'EUR',
 'Facturación en la TERMINAL 2 de Barajas, mostradores 401–411. 20 kg facturados y 10 kg de cabina por persona. Llegada a Orly 20:35.',10),
('van-barajas','Van 9 plazas · 13 días','van','comprado','2026-10-02','15:00',null,'DiscoverCars / Travel Drive','D015193232','https://www.discovercars.com',945.01,'EUR',
 'Recogida y devolución en Barajas: 2 oct 15:00 → 15 oct 15:00. Full Coverage. EN EL MOSTRADOR HACEN FALTA: el voucher, la tarjeta de CRÉDITO física del conductor, la licencia de conducir y el pasaporte. Aparte quedan el depósito y el diésel.',20),
('casa-cordoba','Alojamiento en Córdoba','casa','reservado','2026-10-02','20:15',null,'','','',null,'USD','Entra 2 oct · sale 3 oct · 1 noche. Llegáis de noche: avisar si el registro es presencial.',30),
('casa-sevilla','Alojamiento en Sevilla','casa','reservado','2026-10-03','17:00',null,'','','',null,'USD','Entra 3 oct · sale 6 oct · 3 noches.',31),
('casa-ronda','Alojamiento en Ronda','casa','reservado','2026-10-06','12:00',null,'','','',null,'USD','Entra 6 oct · sale 8 oct · 2 noches.',32),
('casa-almunecar','Alojamiento en Almuñécar','casa','reservado','2026-10-08','19:35',null,'','','',null,'USD','Entra 8 oct · sale 13 oct · 5 noches. A 5 min andando de la playa.',33),
('casa-granada','Alojamiento en Granada','casa','reservado','2026-10-13','11:30',null,'','','',null,'USD','Entra 13 oct · sale 14 oct · 1 noche. Check-in a las 11:30, antes de la hora normal: confirmar que se pueden dejar las maletas.',34),
('casa-madrid','Alojamiento junto a Barajas','casa','reservado','2026-10-14','20:15',null,'','','',null,'USD','Entra 14 oct · sale 15 oct · 1 noche.',35),
('mezquita','Mezquita-Catedral de Córdoba','entrada','pendiente','2026-10-03','09:30','2026-10-02','Cabildo de Córdoba','','https://tickets.mezquita-catedraldecordoba.es/es',null,'EUR',
 'Entrada con hora. 15 € general y 12 € reducida: las abuelas pagan menos. La franja gratuita de 08:30–09:30 NO sirve, es solo individual y máximo 2 personas. OJO: ese sábado hay procesión extraordinaria en Córdoba (San Francisco de Asís, 800 aniversario), puede afectar a accesos.',40),
('alcazar-sevilla','Real Alcázar de Sevilla','entrada','pendiente','2026-10-05','09:30','2026-10-02','Real Alcázar','','https://alcazarsevilla.org',null,'EUR',
 'Entrada con hora. El primer turno es 09:30, no 09:00. 15,50 € general y 8 € las abuelas (mayores de 65). Se agota.',41),
('tablao-sevilla','Tablao de flamenco en Sevilla','actividad','pendiente','2026-10-05','22:00','2026-10-03','Tablao El Arenal','','https://centralreservas.tablaoelarenal.com/booking-center/',null,'EUR',
 'Aforo de 110 plazas. Para 8 juntos, mejor por teléfono: +34 954 216 492. Unos 44 €/pers. con copa. CONFIRMAR que admiten a una niña de 3 años y a qué pase.',42),
('bodega-ronda','Bodega Joaquín Fernández · cata','actividad','pendiente','2026-10-06','15:30','2026-10-04','Bodega Joaquín Fernández','','https://www.bodegajf.es/es/visitas-y-eventos',null,'EUR',
 'Reserva por teléfono o formulario. Unos 15 €/pers. directo en bodega (los 20 € son el precio del intermediario). 90 min, viñedo, bodega y cata de 4 vinos con ibéricos. A 3 km de Ronda.',43),
('almazara-ronda','LA Almazara – LA Organic · cata de aceite','actividad','pendiente','2026-10-08','10:30','2026-10-05','LA Organic','','https://booking.almazaralaorganic.com/es/visits',null,'EUR',
 '25 €/pers., 1 h 30. NO hay pase a las 10:00: los pases son 10:30, 12:30 y 15:00. A-367 km 39,5, carretera Ronda–Ardales.',44),
('caminito-del-rey','Caminito del Rey','actividad','pendiente','2026-10-08',null,'2026-10-03','Caminito del Rey','','https://www.caminitodelrey.info/es/entradas/comprar',null,'EUR',
 'PENDIENTE DE DECIDIR CON EL GRUPO. Edad mínima 8 años: Elina no entra, se queda un adulto con ella en los embalses. 7,7 km y 3–4 h. General 10 € + lanzadera 2,50 €. PIDEN DOCUMENTO EN LA PUERTA. NO HAY CANCELACIÓN GRATUITA: lo que se compra, comprado está.',45),
('kayak-maro','Kayak o barco a los acantilados de Maro','actividad','pendiente','2026-10-11','16:30',null,'','','',null,'EUR',
 'Se reserva allí, con un día de antelación: en la oficina de turismo del Balcón de Europa o en la caseta de Burriana. Así sabréis además si el mar está para salir.',46),
('alhambra','Alhambra · AGOTADA','entrada','sin-reserva','2026-10-13',null,null,'Patronato de la Alhambra','','https://tickets.alhambra-patronato.es/',null,'EUR',
 'Octubre entero agotado en todos los productos: Visita General, Jardines/Generalife/Alcazaba, Dobla de Oro, nocturna y Granada Card. El miércoles 14 se sube igual a la ZONA LIBRE del recinto, que no pide entrada. Último cartucho: la web libera cancelaciones a las 00:00 hora de Granada (17:00 del día anterior en Ecuador), mirar los días 10, 11 y 12.',47),
('pasaportes','Pasaportes de los 8','documento','pendiente',null,null,'2026-10-01','','','',null,'EUR',
 'Súbelos escaneados aquí. Los piden en el Caminito del Rey y los pedirían en la Alhambra. Y si se pierde uno en el viaje, tener el escaneo cambia mucho las cosas.',50),
('licencia','Licencia de conducir y tarjeta de crédito','documento','pendiente',null,null,'2026-10-01','','','',null,'EUR',
 'Para el mostrador de la van, mañana. La licencia ecuatoriana vale en España para un visitante y está en español: no hace falta permiso internacional. La tarjeta tiene que ser de CRÉDITO, física y a nombre del conductor.',51)
on conflict (id) do nothing;
