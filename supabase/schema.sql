-- Portfolio Vue + Supabase
-- Run this script in Supabase SQL Editor using a project owner account.
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.project_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.project_categories(id) on delete set null,
  title text not null,
  slug text not null unique,
  summary text,
  description text,
  thumbnail_url text,
  live_url text,
  repository_url text,
  status text not null default 'draft' check (status in ('draft','published')),
  featured boolean not null default false,
  sort_order integer not null default 0,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.site_profile (
  id uuid primary key default gen_random_uuid(),
  display_name text not null default 'Your Name',
  headline text,
  bio text,
  avatar_url text,
  location text,
  email text,
  seo_title text,
  seo_description text,
  updated_at timestamptz not null default now()
);

create table if not exists public.skills (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  proficiency integer check (proficiency between 0 and 100),
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.experiences (
  id uuid primary key default gen_random_uuid(),
  organization text not null,
  role text not null,
  employment_type text,
  location text,
  description text,
  start_date date,
  end_date date,
  is_current boolean not null default false,
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.education (
  id uuid primary key default gen_random_uuid(),
  institution text not null,
  qualification text,
  field_of_study text,
  description text,
  start_date date,
  end_date date,
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.certificates (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  issuer text,
  credential_url text,
  issued_at date,
  image_url text,
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  icon text,
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.social_links (
  id uuid primary key default gen_random_uuid(),
  platform text not null,
  label text,
  url text not null,
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  subject text,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists projects_status_sort_idx on public.projects(status, featured desc, sort_order asc);
create index if not exists projects_category_id_idx on public.projects(category_id);
create index if not exists experiences_visible_sort_idx on public.experiences(is_visible, sort_order);
create index if not exists skills_visible_sort_idx on public.skills(is_visible, sort_order);

create or replace function public.is_portfolio_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users au
    where au.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_portfolio_admin() from public;
grant execute on function public.is_portfolio_admin() to anon, authenticated;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists projects_set_updated_at on public.projects;
create trigger projects_set_updated_at before update on public.projects
for each row execute function public.set_updated_at();

alter table public.admin_users enable row level security;
alter table public.project_categories enable row level security;
alter table public.projects enable row level security;
alter table public.site_profile enable row level security;
alter table public.skills enable row level security;
alter table public.experiences enable row level security;
alter table public.education enable row level security;
alter table public.certificates enable row level security;
alter table public.services enable row level security;
alter table public.social_links enable row level security;
alter table public.contact_messages enable row level security;

-- Remove named policies before recreation so this script is safe to rerun.
drop policy if exists "Admins can read admin list" on public.admin_users;
create policy "Admins can read admin list" on public.admin_users
for select to authenticated using ((select public.is_portfolio_admin()));

drop policy if exists "Public read categories" on public.project_categories;
create policy "Public read categories" on public.project_categories
for select to anon, authenticated using (true);
drop policy if exists "Admins manage categories" on public.project_categories;
create policy "Admins manage categories" on public.project_categories
for all to authenticated using ((select public.is_portfolio_admin())) with check ((select public.is_portfolio_admin()));

drop policy if exists "Public read published projects" on public.projects;
create policy "Public read published projects" on public.projects
for select to anon, authenticated using (status = 'published' or (select public.is_portfolio_admin()));
drop policy if exists "Admins manage projects" on public.projects;
create policy "Admins manage projects" on public.projects
for all to authenticated using ((select public.is_portfolio_admin())) with check ((select public.is_portfolio_admin()));

-- Public content tables: public reads visible content, admins manage all rows.
drop policy if exists "Public read profile" on public.site_profile;
create policy "Public read profile" on public.site_profile
for select to anon, authenticated using (true);
drop policy if exists "Admins manage profile" on public.site_profile;
create policy "Admins manage profile" on public.site_profile
for all to authenticated using ((select public.is_portfolio_admin())) with check ((select public.is_portfolio_admin()));

drop policy if exists "Public read visible skills" on public.skills;
create policy "Public read visible skills" on public.skills
for select to anon, authenticated using (is_visible or (select public.is_portfolio_admin()));
drop policy if exists "Admins manage skills" on public.skills;
create policy "Admins manage skills" on public.skills
for all to authenticated using ((select public.is_portfolio_admin())) with check ((select public.is_portfolio_admin()));

drop policy if exists "Public read visible experiences" on public.experiences;
create policy "Public read visible experiences" on public.experiences
for select to anon, authenticated using (is_visible or (select public.is_portfolio_admin()));
drop policy if exists "Admins manage experiences" on public.experiences;
create policy "Admins manage experiences" on public.experiences
for all to authenticated using ((select public.is_portfolio_admin())) with check ((select public.is_portfolio_admin()));

drop policy if exists "Public read visible education" on public.education;
create policy "Public read visible education" on public.education
for select to anon, authenticated using (is_visible or (select public.is_portfolio_admin()));
drop policy if exists "Admins manage education" on public.education;
create policy "Admins manage education" on public.education
for all to authenticated using ((select public.is_portfolio_admin())) with check ((select public.is_portfolio_admin()));

drop policy if exists "Public read visible certificates" on public.certificates;
create policy "Public read visible certificates" on public.certificates
for select to anon, authenticated using (is_visible or (select public.is_portfolio_admin()));
drop policy if exists "Admins manage certificates" on public.certificates;
create policy "Admins manage certificates" on public.certificates
for all to authenticated using ((select public.is_portfolio_admin())) with check ((select public.is_portfolio_admin()));

drop policy if exists "Public read visible services" on public.services;
create policy "Public read visible services" on public.services
for select to anon, authenticated using (is_visible or (select public.is_portfolio_admin()));
drop policy if exists "Admins manage services" on public.services;
create policy "Admins manage services" on public.services
for all to authenticated using ((select public.is_portfolio_admin())) with check ((select public.is_portfolio_admin()));

drop policy if exists "Public read visible social links" on public.social_links;
create policy "Public read visible social links" on public.social_links
for select to anon, authenticated using (is_visible or (select public.is_portfolio_admin()));
drop policy if exists "Admins manage social links" on public.social_links;
create policy "Admins manage social links" on public.social_links
for all to authenticated using ((select public.is_portfolio_admin())) with check ((select public.is_portfolio_admin()));

drop policy if exists "Admins read contact messages" on public.contact_messages;
create policy "Admins read contact messages" on public.contact_messages
for select to authenticated using ((select public.is_portfolio_admin()));
drop policy if exists "Admins update contact messages" on public.contact_messages;
create policy "Admins update contact messages" on public.contact_messages
for update to authenticated using ((select public.is_portfolio_admin())) with check ((select public.is_portfolio_admin()));
drop policy if exists "Admins delete contact messages" on public.contact_messages;
create policy "Admins delete contact messages" on public.contact_messages
for delete to authenticated using ((select public.is_portfolio_admin()));
-- Public insert for contact messages is intentionally NOT enabled yet.
-- Add a validated server-side/edge-function flow or a carefully rate-limited insert policy before launching a public contact form.

grant select on public.project_categories, public.projects, public.site_profile, public.skills,
  public.experiences, public.education, public.certificates, public.services, public.social_links
to anon, authenticated;
grant select, insert, update, delete on public.project_categories, public.projects, public.site_profile,
  public.skills, public.experiences, public.education, public.certificates, public.services, public.social_links
to authenticated;
grant select, update, delete on public.contact_messages to authenticated;
grant select on public.admin_users to authenticated;

-- Optional starter category data
insert into public.project_categories (name, slug)
values ('Web Development', 'web-development'), ('Creative', 'creative'), ('Tools & Experiments', 'tools-experiments')
on conflict (slug) do nothing;

-- After creating your own admin user in Supabase Auth, run this separately:
-- insert into public.admin_users (user_id) values ('PASTE_AUTH_USER_UUID_HERE');
