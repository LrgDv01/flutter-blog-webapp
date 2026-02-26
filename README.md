# Flutter Blog Web App

Simple blog web app built with Flutter, Supabase, Riverpod, and GoRouter.

## Features

- Email/password authentication (register, login, logout)
- Protected routes with auth redirect flow
- Create, read, update, delete posts
- Single cover image upload for posts
- Comments with optional image upload
- Owner-only controls for edit/delete on posts and comments
- Display names from `profiles` table
- Loading and error states for posts/comments
- Pull-to-refresh on Home and Post Detail
- Delete confirmation dialogs

## Tech Stack

- Flutter (Material 3 UI)
- Flutter Riverpod (state management)
- GoRouter (routing + auth guard)
- Supabase (Auth, Postgres, Storage)
- `image_picker` + `cached_network_image`
- `flutter_dotenv` for local env config

## Project Structure

```text
lib/
  main.dart
  router.dart
  supabase_client.dart
  models/
    post.dart
    comment.dart
    profile.dart
  providers/
    auth_provider.dart
    posts_provider.dart
    profile_provider.dart
  pages/
    login_page.dart
    register_page.dart
    home_page.dart
    create_post_page.dart
    post_detail_page.dart
    edit_post_page.dart
```

## Prerequisites

- Flutter SDK (stable channel)
- Chrome or Edge for web run target
- Supabase project

## Environment Setup

This project loads env values from `assets/.env`.

1. Create `assets/.env`
2. Add:

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

3. Ensure `assets/.env` is listed in `pubspec.yaml` assets (already configured)

## Supabase Setup

Create these tables in `public` schema:

- `profiles`: `id`, `user_id`, `display_name`, `avatar_url`, `created_at`
- `posts`: `id`, `user_id`, `title`, `content`, `image_url`, `created_at`, `updated_at`
- `comments`: `id`, `post_id`, `user_id`, `content`, `image_url`, `author_name` (optional), `created_at`, `updated_at`

Create storage bucket:

- `post_images` (public)

### Recommended SQL (RLS + policies)

```sql
-- PROFILES
alter table public.profiles enable row level security;

create policy "profiles_select_own"
on public.profiles for select
using (auth.uid() = user_id);

create policy "profiles_insert_own"
on public.profiles for insert
with check (auth.uid() = user_id);

create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Optional: auto-create profile on sign up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (user_id, display_name)
  values (new.id, new.raw_user_meta_data->>'display_name');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- POSTS
alter table public.posts enable row level security;

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

-- COMMENTS
alter table public.comments enable row level security;

create policy "comments_select_all"
on public.comments for select
using (true);

create policy "comments_insert_own"
on public.comments for insert
with check (auth.uid() = user_id);

create policy "comments_delete_own"
on public.comments for delete
using (auth.uid() = user_id);
```

## Run Locally

```bash
flutter pub get
flutter run -d chrome
```

Optional:

```bash
flutter run -d chrome --wasm
```

## Quality Checks

```bash
flutter analyze
flutter test
```

## Troubleshooting

- White screen on startup:
  - Check `assets/.env` exists and has correct keys.
  - Confirm `pubspec.yaml` includes `assets/.env`.
- Login/register succeeds but data queries fail:
  - Recheck RLS policies on `profiles`, `posts`, `comments`.
- Image upload fails:
  - Recheck `post_images` bucket and storage policies.

## Current Status

Core assessment scope is implemented:

- Auth flow
- Posts CRUD with image support
- Comments with image support
- Profile display names
- Loading/error/refresh UX improvements
