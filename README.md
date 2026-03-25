# Flutter Blog Web App

A Flutter web blog application built with Supabase, Riverpod, and GoRouter.

## Features

- Email/password authentication with register, login, and logout flows
- Protected routes with auth-based redirects
- Posts CRUD with optional cover image upload
- Anonymous posting support
- Comments CRUD with optional image upload
- Anonymous comments, plus edit support for text, image, and anonymity
- Profile page with editable display name and avatar upload/remove
- Shared profile cache so author names and avatars appear across the app
- Inline, dialog, and page-level error handling
- Pull-to-refresh on the feed and post detail page
- Delete confirmation dialogs for posts, comments, and logout
- Vercel deployment scripts for Flutter web

## Tech Stack

- Flutter (Material 3)
- Flutter Riverpod
- GoRouter
- Supabase Auth, Postgres, and Storage
- `image_picker`
- `cached_network_image`
- `flutter_dotenv` for local development fallback

## Project Structure

```text
lib/
  main.dart
  router.dart
  supabase_client.dart
  models/
    comment.dart
    post.dart
    profile.dart
  pages/
    create_post_page.dart
    edit_post_page.dart
    home_page.dart
    login_page.dart
    post_detail_page.dart
    profile_page.dart
    register_page.dart
  providers/
    auth_provider.dart
    comments_provider.dart
    posts_provider.dart
    profile_provider.dart
  utils/
    error_utils.dart
  widgets/
    inline_error_banner.dart
scripts/
  vercel-build.sh
  vercel-install.sh
vercel.json
```

## Prerequisites

- Flutter SDK (stable)
- Chrome or Edge for local web testing
- A Supabase project
- A Vercel account if you want production deployment

## Environment Setup

This app supports two configuration modes:

- Local development: `assets/.env`
- Production builds: `--dart-define`

### Local Development

Create `assets/.env`:

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

Notes:

- `assets/.env` is intentionally gitignored
- [lib/supabase_client.dart](lib/supabase_client.dart) first checks `String.fromEnvironment(...)`
- if no `--dart-define` values are present, it falls back to `assets/.env`

## Supabase Setup

Create these tables in the `public` schema.

### `profiles`

Required columns:

- `id uuid primary key default gen_random_uuid()`
- `user_id uuid unique references auth.users(id)`
- `display_name text`
- `avatar_url text`
- `created_at timestamptz default now()`
- `updated_at timestamptz`

### `posts`

Required columns:

- `id uuid primary key default gen_random_uuid()`
- `user_id uuid references auth.users(id)`
- `title text`
- `content text`
- `image_url text`
- `is_anonymous boolean default false`
- `created_at timestamptz default now()`
- `updated_at timestamptz`

### `comments`

Required columns:

- `id uuid primary key default gen_random_uuid()`
- `post_id uuid references public.posts(id) on delete cascade`
- `user_id uuid references auth.users(id)`
- `content text`
- `image_url text`
- `author_name text`
- `is_anonymous boolean default false`
- `created_at timestamptz default now()`
- `updated_at timestamptz`

### Storage Buckets

Create these public buckets:

- `post_images`
- `avatars`

## Recommended RLS Policies

Enable RLS:

```sql
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
```

### Profiles

Your current UI needs all signed-in users to be able to read profile rows for author names and avatars.

```sql
create policy "profiles_select_all"
on public.profiles for select
using (true);

create policy "profiles_insert_own"
on public.profiles for insert
with check (auth.uid() = user_id);

create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
```

### Posts

```sql
create policy "posts_select_all"
on public.posts for select
using (true);

create policy "posts_insert_own"
on public.posts for insert
with check (auth.uid() = user_id);

create policy "posts_update_own"
on public.posts for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "posts_delete_own"
on public.posts for delete
using (auth.uid() = user_id);
```

### Comments

```sql
create policy "comments_select_all"
on public.comments for select
using (true);

create policy "comments_insert_own"
on public.comments for insert
with check (auth.uid() = user_id);

create policy "comments_update_own"
on public.comments for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "comments_delete_own"
on public.comments for delete
using (auth.uid() = user_id);
```

## Auto-Create Profile on Sign Up

This trigger creates a `profiles` row whenever a new auth user is created:

```sql
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    user_id,
    display_name
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', 'Anonymous User')
  );

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();
```

If you created users before adding that trigger, backfill their profile rows manually.

## Run Locally

```bash
flutter pub get
flutter run -d chrome
```

Optional production-style local build:

```bash
flutter build web --release --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
```

## Deployment on Vercel

This repo is already configured for Vercel in:

- [vercel.json](vercel.json)
- [scripts/vercel-install.sh](scripts/vercel-install.sh)
- [scripts/vercel-build.sh](scripts/vercel-build.sh)

### Deployment Notes

- Vercel does not provide Flutter by default for this project setup
- `vercel-install.sh` downloads Flutter stable and enables web support
- `vercel-build.sh` builds the app with `--dart-define`
- the script also creates a placeholder `assets/.env` because Flutter validates declared assets during the build

### Required Vercel Environment Variables

Set these in Vercel Project Settings:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

### Current Routing Note

The app currently uses hash-style web URLs such as:

- `/#/login`
- `/#/home`
- `/#/profile`

Because of that, no SPA rewrite rule is required for the current deployment setup.

## Quality Checks

```bash
flutter analyze
flutter test
```

## Troubleshooting

### Build fails with missing Supabase configuration

- Check `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- locally, confirm `assets/.env` exists
- in production, confirm Vercel environment variables are set

### Profiles return empty data

Check both:

- the profile row actually exists
- `profiles` select policy is not restricted to only `auth.uid() = user_id`

### Comment edit fails

Make sure `comments_update_own` exists.

### Vercel build says `flutter: command not found`

Confirm the repo still includes:

- [vercel.json](vercel.json)
- [scripts/vercel-install.sh](scripts/vercel-install.sh)
- [scripts/vercel-build.sh](scripts/vercel-build.sh)

### Vercel build fails with `No file or variants found for asset: assets/.env`

That is handled by [scripts/vercel-build.sh](scripts/vercel-build.sh), which creates a placeholder asset during the build.

## Current App Scope

Implemented and working in the current codebase:

- Auth flow with inline auth error UI
- Posts CRUD with image and anonymous mode
- Comments CRUD with image and anonymous mode
- Profile editing with avatar support
- Shared display names and avatars across feed and comments
- Error handling and refresh states
- Vercel deployment pipeline for Flutter web
