-- =====================================================================
-- AI Job Hunter — Supabase schema
-- Kahan chalana hai: Supabase Dashboard > SQL Editor > New query > paste > Run
-- Ek dafa poora chalao. Dobara chalane se kuch nahi tootega (IF NOT EXISTS).
-- =====================================================================

-- 1) pgvector extension (CV embeddings ke liye)
create extension if not exists vector with schema extensions;


-- =====================================================================
-- 2) JOBS — WF1 Job Collector yahan har job save karega
-- =====================================================================
create table if not exists public.jobs (
  id            bigint generated always as identity primary key,  -- chhota number: WhatsApp pe "applied 42"
  source        text not null check (source in ('remotive','remoteok','jsearch')),
  external_id   text not null,               -- API ki apni job id
  title         text not null,
  company       text,
  location      text,
  job_type      text,                        -- full_time, contract, etc.
  salary        text,                        -- APIs alag format dete hain, isliye text
  url           text not null,
  description   text,
  tags          text[] default '{}',
  posted_at     timestamptz,
  collected_at  timestamptz not null default now(),
  status        text not null default 'new'
                check (status in ('new','scored','skipped','error')),
  constraint jobs_source_external_unique unique (source, external_id)  -- dedupe ka asal rule
);

create index if not exists jobs_status_idx       on public.jobs (status);
create index if not exists jobs_collected_at_idx on public.jobs (collected_at desc);
create index if not exists jobs_url_idx          on public.jobs (url);


-- =====================================================================
-- 3) JOB_MATCHES — WF2 Job Matcher ka result (score 0–100)
-- =====================================================================
create table if not exists public.job_matches (
  id               bigint generated always as identity primary key,
  job_id           bigint not null unique references public.jobs(id) on delete cascade,
  score            int not null check (score between 0 and 100),
  verdict          text,                     -- e.g. "strong", "maybe", "weak"
  reasoning        text,                     -- LLM ne score kyun diya
  matched_skills   text[] default '{}',
  missing_skills   text[] default '{}',
  model            text,                     -- kaunsa Gemini model use hua
  created_at       timestamptz not null default now()
);

create index if not exists job_matches_score_idx on public.job_matches (score desc);


-- =====================================================================
-- 4) COVER_LETTERS — WF3 sirf score >= 70 wali jobs ke liye
-- =====================================================================
create table if not exists public.cover_letters (
  id          bigint generated always as identity primary key,
  job_id      bigint not null unique references public.jobs(id) on delete cascade,
  content     text not null,
  model       text,
  created_at  timestamptz not null default now()
);


-- =====================================================================
-- 5) APPLICATIONS — WhatsApp "applied <id>" yahan entry banaye ga
-- =====================================================================
create table if not exists public.applications (
  id          bigint generated always as identity primary key,
  job_id      bigint not null unique references public.jobs(id) on delete cascade,
  status      text not null default 'applied'
              check (status in ('saved','applied','interview','rejected','offer')),
  applied_at  timestamptz default now(),
  notes       text,
  updated_at  timestamptz not null default now()
);


-- =====================================================================
-- 6) WORKFLOW_ERRORS — WF5 Error Guard log (optional lekin useful)
-- =====================================================================
create table if not exists public.workflow_errors (
  id             bigint generated always as identity primary key,
  workflow_name  text,
  node_name      text,
  error_message  text,
  execution_url  text,
  created_at     timestamptz not null default now()
);


-- =====================================================================
-- 7) CV_CHUNKS — WF0 CV Brain (pgvector)
-- Column names n8n "Supabase Vector Store" node ke mutabiq hain:
-- id, content, metadata, embedding — inko rename mat karna.
-- Dimension 3072 = gemini-embedding-001 ka default output.
-- (Index nahi lagaya: pgvector index 2000 dims tak hi hota hai, aur CV
--  ke ~20–50 chunks ke liye index ki zaroorat bhi nahi.)
-- =====================================================================
create table if not exists public.cv_chunks (
  id         bigserial primary key,
  content    text,
  metadata   jsonb,
  embedding  extensions.vector(3072)
);

-- n8n is function ko call karta hai similarity search ke liye
-- (node mein "Query Name" = match_cv_chunks likhna hoga)
create or replace function public.match_cv_chunks (
  query_embedding extensions.vector(3072),
  match_count     int   default null,
  filter          jsonb default '{}'
) returns table (
  id          bigint,
  content     text,
  metadata    jsonb,
  similarity  float
)
language plpgsql
set search_path = public, extensions
as $$
begin
  return query
  select
    cv_chunks.id,
    cv_chunks.content,
    cv_chunks.metadata,
    1 - (cv_chunks.embedding <=> query_embedding) as similarity
  from cv_chunks
  where cv_chunks.metadata @> filter
  order by cv_chunks.embedding <=> query_embedding
  limit match_count;
end;
$$;


-- =====================================================================
-- 8) JOB_DASHBOARD view — WF4 WhatsApp agent isko read karega
-- Ek hi jagah: job + score + cover letter hai ya nahi + applied status
-- =====================================================================
create or replace view public.job_dashboard
with (security_invoker = true) as
select
  j.id,
  j.title,
  j.company,
  j.location,
  j.url,
  j.source,
  j.collected_at,
  m.score,
  m.verdict,
  (c.id is not null)              as has_cover_letter,
  coalesce(a.status, 'not_applied') as application_status,
  a.applied_at
from public.jobs j
left join public.job_matches   m on m.job_id = j.id
left join public.cover_letters c on c.job_id = j.id
left join public.applications  a on a.job_id = j.id;


-- =====================================================================
-- 9) Security: RLS ON, koi policy nahi
-- Matlab public "anon" key se koi data nahi parh sakta.
-- n8n "service_role / secret" key use karega jo RLS bypass karti hai.
-- =====================================================================
alter table public.jobs            enable row level security;
alter table public.job_matches     enable row level security;
alter table public.cover_letters   enable row level security;
alter table public.applications    enable row level security;
alter table public.workflow_errors enable row level security;
alter table public.cv_chunks       enable row level security;


-- =====================================================================
-- 10) Quick check — yeh chala ke dekho sab tables bani ya nahi
-- =====================================================================
-- select table_name from information_schema.tables
-- where table_schema = 'public' order by table_name;
