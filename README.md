# Portfolio Vue + Supabase

Starter implementation for a dark-modern personal portfolio. This project uses Vue 3, Vite, JavaScript, Vue Router, Bootstrap 5, Supabase Auth, PostgreSQL and Supabase Storage. No Laravel or custom PHP backend is required.

## Requirements

- Node.js 20.19+ or 22.12+ (recommended for Vite 7)
- npm
- A Supabase project
- Git (optional, for deployment)

## 1. Install and run

```bash
npm install
cp .env.example .env.local
npm run dev
```

Open the local URL printed by Vite, usually `http://localhost:5173`.

## 2. Configure Supabase

1. Create a project at https://supabase.com.
2. Open **Project Settings → API** (or the API keys page in the current dashboard).
3. Copy the Project URL and the publishable key (legacy anon key is also supported).
4. Put them in `.env.local`:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

Never put a `service_role` key or any secret key in a `VITE_` variable. Anything prefixed with `VITE_` is shipped to the browser.

## 3. Create database tables and policies

1. In Supabase, open **SQL Editor**.
2. Paste and run `supabase/schema.sql`.
3. In **Authentication → Users**, create an administrator account with email and password. Keep public sign-ups disabled if this is a single-admin portfolio.
4. Copy that user's UUID.
5. Run the following in SQL Editor, replacing the UUID:

```sql
insert into public.admin_users (user_id)
values ('PASTE_AUTH_USER_UUID_HERE');
```

The `admin_users` allowlist determines who can manage portfolio content. Creating an Auth user alone does not grant admin access.

## 4. Configure storage

Run `supabase/storage.sql` in SQL Editor. It creates a public `portfolio-assets` bucket for public portfolio images while restricting upload/update/delete operations to allowlisted admins. The first CRUD screen currently accepts an image URL; direct upload UI is a next implementation step.

## 5. Build

```bash
npm run build
npm run preview
```

The production build is written to `dist/`.

## 6. Deploy to Cloudflare Pages

1. Push the repository to GitHub.
2. In Cloudflare, create a Pages project connected to that repository.
3. Build command: `npm run build`
4. Build output directory: `dist`
5. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` in the Pages environment variables for Production and Preview.
6. Deploy and test `/`, `/projects/example-slug`, `/admin/login`, and `/admin/projects`.

This app uses Vue Router history mode. Configure a Pages SPA fallback (Cloudflare Pages normally serves the SPA entry point when no matching static asset exists). Confirm direct navigation to nested routes after deployment.

## Current implementation scope

- Dark responsive public landing page.
- Published project listing and project detail.
- Supabase email/password admin login.
- Admin dashboard with project counts.
- Create/read/update/delete project records.
- Draft/published status and featured ordering.
- SQL schema and RLS policies for planned content tables.
- Storage bucket policies for public images and admin-only writes.

## Next implementation steps

1. Add file upload UI connected to `portfolio-assets`.
2. Add CRUD pages for profile, categories, skills, experiences, education, certificates, services and social links.
3. Connect the public sections to the corresponding tables.
4. Add contact form handling with spam protection (prefer a Supabase Edge Function or another server-side validated endpoint).
5. Add SEO metadata per project, Open Graph tags, sitemap, and final accessibility/performance checks.

## Security checklist

- Keep `service_role` and secret keys out of the frontend and Git.
- Keep RLS enabled on every exposed table.
- Add only trusted user UUIDs to `admin_users`.
- Disable public Auth sign-ups if only the owner should log in.
- Test using an anonymous session that draft projects cannot be read.
- Test that a signed-in non-admin cannot insert/update/delete rows.
- Public storage means anyone can view known asset URLs. Do not upload private files to this bucket.
