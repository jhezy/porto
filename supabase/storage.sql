-- Create a bucket named "portfolio-assets" in Supabase Storage first.
-- Set it to PUBLIC only if public thumbnails should load via public URLs.
-- Public can read files; only registered portfolio admins can upload/update/delete.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('portfolio-assets', 'portfolio-assets', true, 5242880, array['image/jpeg','image/png','image/webp','image/avif'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public read portfolio assets" on storage.objects;
create policy "Public read portfolio assets" on storage.objects
for select to anon, authenticated using (bucket_id = 'portfolio-assets');

drop policy if exists "Admins upload portfolio assets" on storage.objects;
create policy "Admins upload portfolio assets" on storage.objects
for insert to authenticated with check (
  bucket_id = 'portfolio-assets' and (select public.is_portfolio_admin())
);

drop policy if exists "Admins update portfolio assets" on storage.objects;
create policy "Admins update portfolio assets" on storage.objects
for update to authenticated using (
  bucket_id = 'portfolio-assets' and (select public.is_portfolio_admin())
) with check (
  bucket_id = 'portfolio-assets' and (select public.is_portfolio_admin())
);

drop policy if exists "Admins delete portfolio assets" on storage.objects;
create policy "Admins delete portfolio assets" on storage.objects
for delete to authenticated using (
  bucket_id = 'portfolio-assets' and (select public.is_portfolio_admin())
);
