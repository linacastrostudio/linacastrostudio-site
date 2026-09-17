-- Lina Castro Studio — portfolio schema
-- Run this once in the Supabase Dashboard: SQL Editor > New query > paste > Run.
-- Safe to re-run (uses IF NOT EXISTS / ON CONFLICT DO NOTHING where sensible).

create table if not exists projects (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  tag text not null,
  categories text[] not null default '{}',
  project_date date not null,
  brief text not null default '',
  deliverables text[] not null default '{}',
  palette text[] not null default '{}',
  cover_image_url text,
  cover_alt text default '',
  published boolean not null default true,
  sort_order int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists project_images (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  image_url text not null,
  alt text not null default '',
  description text not null default '',
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table projects enable row level security;
alter table project_images enable row level security;

-- Public site: only published projects/images are visible to anon visitors.
create policy "public read published projects" on projects
  for select to anon
  using (published = true);

create policy "public read images of published projects" on project_images
  for select to anon
  using (exists (select 1 from projects p where p.id = project_images.project_id and p.published = true));

-- Admin (Lina, the only authenticated user — no public signup): full access.
create policy "authenticated read all projects" on projects
  for select to authenticated using (true);
create policy "authenticated insert projects" on projects
  for insert to authenticated with check (true);
create policy "authenticated update projects" on projects
  for update to authenticated using (true) with check (true);
create policy "authenticated delete projects" on projects
  for delete to authenticated using (true);

create policy "authenticated read all images" on project_images
  for select to authenticated using (true);
create policy "authenticated insert images" on project_images
  for insert to authenticated with check (true);
create policy "authenticated update images" on project_images
  for update to authenticated using (true) with check (true);
create policy "authenticated delete images" on project_images
  for delete to authenticated using (true);

-- keep updated_at fresh
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists projects_set_updated_at on projects;
create trigger projects_set_updated_at
  before update on projects
  for each row execute function set_updated_at();

-- Storage bucket for uploaded photos (public read, admin-only write)
insert into storage.buckets (id, name, public)
values ('project-images', 'project-images', true)
on conflict (id) do nothing;

create policy "public read project images bucket" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'project-images');

create policy "authenticated upload project images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'project-images');

create policy "authenticated update project images bucket" on storage.objects
  for update to authenticated
  using (bucket_id = 'project-images');

create policy "authenticated delete project images bucket" on storage.objects
  for delete to authenticated
  using (bucket_id = 'project-images');

-- Seed the 6 existing projects (safe to re-run: skips rows whose slug already exists)
insert into projects (slug, title, tag, categories, project_date, brief, deliverables, palette, cover_image_url, cover_alt, published)
select * from (values
  ('croomie', 'Croomie', 'Branding + Packaging', array['Branding','Packaging'], date '2025-01-01',
    'Una identidad juguetona y cercana para una marca de snacks saludables. El empaque combina tipografía orgánica y colores vibrantes que comunican frescura y bienestar, invitando al consumidor a disfrutar sin culpa en cada bocado.',
    array['Logotipo y variantes','Paleta de color','Tipografía de marca','Manual de uso básico','Aplicación en empaque'],
    array['#a0aacb','#26211e','#010000','#7b7a82'],
    'assets/images/croomie-portada.png', 'Empaque de la marca Croomie', true),
  ('trivium-barber-club', 'Trivium Barber Club', 'Identidad de marca', array['Branding'], date '2024-01-01',
    'Una identidad sobria y masculina inspirada en la tradición de la barbería clásica. El logotipo circular en tonos verde oscuro y dorado transmite elegancia atemporal, ideal para un espacio que mezcla estilo urbano y ritual de cuidado personal.',
    array['Logotipo y variantes','Paleta de color','Tipografía de marca','Manual de uso básico'],
    array['#0f6158','#4f3f36','#8a817d','#fbfcfb'],
    'assets/images/trivium-barber-club-portada.png', 'Señalética de Trivium Barber Club', true),
  ('twins-beauty-salon-barber', 'Twins Beauty Salon & Barber', 'Identidad de marca', array['Branding'], date '2024-01-01',
    'Diseño de identidad para un salón que fusiona belleza y barbería en un solo concepto. La tipografía caligráfica y la paleta cálida en tonos tierra reflejan calidez, cercanía y el vínculo de confianza entre el cliente y su estilista.',
    array['Logotipo y variantes','Paleta de color','Tipografía de marca','Manual de uso básico'],
    array['#ac866e','#fcecdf','#cab8a6','#7a5939'],
    'assets/images/twins-beauty-salon-barber-portada.png', 'Papelería de Twins Beauty Salon & Barber', true),
  ('gustossia', 'Gustossia', 'Identidad de marca', array['Branding'], date '2023-01-01',
    'Identidad fresca y natural para una heladería y jugería artesanal. Los tonos verdes y la ilustración botánica refuerzan el mensaje "creamos momentos dulces", conectando con un público que busca placer y frescura en cada visita.',
    array['Logotipo y variantes','Paleta de color','Tipografía de marca','Manual de uso básico'],
    array['#71684c','#bba68d','#0d0b04','#433b2e'],
    'assets/images/gustossia-portada.png', 'Fachada de la tienda Gustossia', true),
  ('velmora-beauty', 'Velmora Beauty', 'Identidad de marca + UI/UX', array['Branding','UI/UX'], date '2023-06-01',
    'Una identidad femenina y sofisticada para una marca de cuidado personal. El diseño combina líneas orgánicas en tono burdeos con una experiencia digital pensada para acompañar el ritual de belleza del cliente en cada punto de contacto.',
    array['Logotipo y variantes','Paleta de color','Tipografía de marca','Manual de uso básico','Diseño de interfaz UI/UX'],
    array['#5c272c','#e9c4cd','#1d100e','#a96569'],
    'assets/images/velmora-beauty-portada.png', 'Bolsa de tela de Velmora Beauty', true),
  ('saga', 'Saga', 'Identidad de marca', array['Branding'], date '2022-01-01',
    'Identidad digital vibrante para una marca de tecnología accesible para todos. El naranja cálido y la ilustración amigable transmiten cercanía e innovación, haciendo que la tecnología se sienta simple, humana y al alcance de cualquiera.',
    array['Logotipo y variantes','Paleta de color','Tipografía de marca','Manual de uso básico'],
    array['#d16c55','#c9beb0','#77463a','#f8f6f6'],
    'assets/images/saga-portada.png', 'Mockup del sitio web de Saga', true)
) as seed(slug, title, tag, categories, project_date, brief, deliverables, palette, cover_image_url, cover_alt, published)
where not exists (select 1 from projects p where p.slug = seed.slug);
