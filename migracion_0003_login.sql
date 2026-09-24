-- Andalucía 2026 · migración 0003
-- Cierra las tablas: dejan de estar abiertas a cualquiera y pasan a exigir login.
--
-- POR QUÉ. Hasta ahora las políticas eran «for all to anon using (true)», o sea que
-- cualquiera con la anon key podía leer, modificar y BORRAR las casas y los gastos.
-- Y la anon key está en el HTML, que se sirve público por GitHub Pages desde un
-- repositorio público. Con Realtime encima, un borrado se propagaba en vivo a todos
-- los móviles de la familia.
--
-- LO QUE NO HAY QUE HACER. No hace falta rotar la anon key ni poner el repositorio
-- en privado: una anon key está pensada para ser pública y viajar en el HTML. Lo que
-- estaba mal eran las políticas. En cuanto exigen sesión iniciada, esa clave por sí
-- sola no abre nada, que es justo como Supabase está diseñado para funcionar.
--
-- ORDEN DE EJECUCIÓN, importante:
--   1. Crea los usuarios de la familia en el panel (Authentication → Users → Add user),
--      con email y contraseña, y marca «Auto Confirm User».
--   2. Desactiva el registro abierto (Authentication → Sign In / Providers →
--      «Allow new users to sign up» en OFF). Si no, cualquiera se crea una cuenta
--      y volvemos al punto de partida.
--   3. Corre esta migración.
--   4. Publica el index.html con la pantalla de login.
-- Entre el paso 3 y el 4 la web se queda sin datos: hazlos seguidos.

-- ---------- alojamientos ----------
drop policy if exists "alojamientos_anon_all"  on public.alojamientos;
drop policy if exists "alojamientos_auth_sel"  on public.alojamientos;
drop policy if exists "alojamientos_auth_ins"  on public.alojamientos;
drop policy if exists "alojamientos_auth_upd"  on public.alojamientos;
drop policy if exists "alojamientos_auth_del"  on public.alojamientos;

create policy "alojamientos_auth_sel" on public.alojamientos
  for select to authenticated using (true);
create policy "alojamientos_auth_ins" on public.alojamientos
  for insert to authenticated with check (true);
create policy "alojamientos_auth_upd" on public.alojamientos
  for update to authenticated using (true) with check (true);
create policy "alojamientos_auth_del" on public.alojamientos
  for delete to authenticated using (true);

-- ---------- gastos ----------
drop policy if exists "gastos_anon_all" on public.gastos;
drop policy if exists "gastos_auth_sel" on public.gastos;
drop policy if exists "gastos_auth_ins" on public.gastos;
drop policy if exists "gastos_auth_upd" on public.gastos;
drop policy if exists "gastos_auth_del" on public.gastos;

create policy "gastos_auth_sel" on public.gastos
  for select to authenticated using (true);
create policy "gastos_auth_ins" on public.gastos
  for insert to authenticated with check (true);
create policy "gastos_auth_upd" on public.gastos
  for update to authenticated using (true) with check (true);
create policy "gastos_auth_del" on public.gastos
  for delete to authenticated using (true);

-- ---------- Comprobación ----------
-- Después de correr esto, aquí NO debe quedar ninguna fila con roles = {anon}.
-- Si queda alguna, es que hay una política vieja con otro nombre: bórrala.
select tablename, policyname, roles, cmd
from pg_policies
where schemaname = 'public' and tablename in ('alojamientos','gastos')
order by tablename, cmd;
