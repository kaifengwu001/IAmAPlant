-- Daily Rings: Initial Schema
-- Run this against your Supabase project's SQL editor

-- Daily summary (one row per user per day)
create table if not exists daily_summary (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  date date not null,
  timezone text not null default 'UTC',

  -- Sleep
  sleep_start timestamptz,
  sleep_end timestamptz,
  sleep_hours float default 0,
  sleep_score float default 0,
  sleep_screen_minutes int default 0,
  sleep_source text default 'manual',

  -- Exercise
  exercise_minutes int default 0,
  exercise_score float default 0,

  -- Nutrition
  nutrition_score float default 0,
  meal_count int default 0,
  meal_scores jsonb default '[]',

  -- Productivity
  pomodoro_completed int default 0,
  pomodoro_interrupted int default 0,
  pomodoro_total_minutes int default 0,
  rescuetime_productive_minutes int default 0,
  rescuetime_distracting_minutes int default 0,
  overlap_minutes int default 0,
  manual_adjustment_minutes int default 0,
  manual_adjustments jsonb default '[]',
  productive_minutes_total int default 0,
  productivity_score float default 0,

  -- Metadata
  status text default 'partial',
  created_at timestamptz default now(),

  unique(user_id, date)
);

-- Individual Pomodoro sessions
create table if not exists pomodoro_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  date date not null,
  goal_label text not null,
  category text not null,
  start_time timestamptz not null,
  end_time timestamptz,
  completed boolean default false,
  distracted_seconds int default 0,
  duration_minutes int default 0,
  created_at timestamptz default now()
);

-- User preferences
create table if not exists user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  sleep_goal_hours float default 8.0,
  exercise_goal_minutes int default 30,
  productivity_goal_minutes int default 480,
  rescuetime_api_key text,
  day_boundary_hour int default 4,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Row Level Security
alter table daily_summary enable row level security;
alter table pomodoro_sessions enable row level security;
alter table user_settings enable row level security;

-- RLS Policies: users can only access their own data
create policy "Users can view own daily summaries"
  on daily_summary for select
  using (auth.uid() = user_id);

create policy "Users can insert own daily summaries"
  on daily_summary for insert
  with check (auth.uid() = user_id);

create policy "Users can update own daily summaries"
  on daily_summary for update
  using (auth.uid() = user_id);

create policy "Users can delete own daily summaries"
  on daily_summary for delete
  using (auth.uid() = user_id);

create policy "Users can view own pomodoro sessions"
  on pomodoro_sessions for select
  using (auth.uid() = user_id);

create policy "Users can insert own pomodoro sessions"
  on pomodoro_sessions for insert
  with check (auth.uid() = user_id);

create policy "Users can update own pomodoro sessions"
  on pomodoro_sessions for update
  using (auth.uid() = user_id);

create policy "Users can delete own pomodoro sessions"
  on pomodoro_sessions for delete
  using (auth.uid() = user_id);

create policy "Users can view own settings"
  on user_settings for select
  using (auth.uid() = user_id);

create policy "Users can insert own settings"
  on user_settings for insert
  with check (auth.uid() = user_id);

create policy "Users can update own settings"
  on user_settings for update
  using (auth.uid() = user_id);

-- Indexes
create index if not exists idx_daily_summary_user_date on daily_summary(user_id, date);
create index if not exists idx_pomodoro_sessions_user_date on pomodoro_sessions(user_id, date);
create index if not exists idx_daily_summary_status on daily_summary(status);
