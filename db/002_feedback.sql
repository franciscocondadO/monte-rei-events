-- Post-event satisfaction survey (one answer per guest, via personal token)
create table if not exists public.feedback (
  convidado_id uuid primary key references public.convidados(id) on delete cascade,
  overall int check (overall between 1 and 5),
  golf int check (golf between 1 and 5),
  lunch int check (lunch between 1 and 5),
  organisation int check (organisation between 1 and 5),
  presentation int check (presentation between 1 and 5),
  liked text,
  improve text,
  next_year text check (next_year in ('yes','maybe','no')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.feedback enable row level security;

create or replace function public.get_feedback(p_token text)
returns json language sql security definer set search_path to 'public' as $$
  select json_build_object(
    'nome', c.nome, 'joga', coalesce(c.joga,false), 'rsvp', c.rsvp,
    'answered', f.convidado_id is not null,
    'overall', f.overall, 'golf', f.golf, 'lunch', f.lunch,
    'organisation', f.organisation, 'presentation', f.presentation,
    'liked', f.liked, 'improve', f.improve, 'next_year', f.next_year)
  from public.convidados c left join public.feedback f on f.convidado_id = c.id
  where c.token = p_token;
$$;

create or replace function public.set_feedback(
  p_token text, p_overall int, p_golf int, p_lunch int, p_organisation int,
  p_presentation int, p_liked text, p_improve text, p_next_year text)
returns json language plpgsql security definer set search_path to 'public' as $$
declare v_id uuid;
begin
  select id into v_id from public.convidados where token = p_token;
  if v_id is null then return json_build_object('ok', false, 'erro', 'token_invalido'); end if;
  if p_overall is null or p_overall not between 1 and 5 then
    return json_build_object('ok', false, 'erro', 'overall_obrigatorio');
  end if;
  insert into public.feedback(convidado_id, overall, golf, lunch, organisation, presentation, liked, improve, next_year)
  values (v_id, p_overall, p_golf, p_lunch, p_organisation, p_presentation,
          nullif(left(trim(p_liked),2000),''), nullif(left(trim(p_improve),2000),''), nullif(p_next_year,''))
  on conflict (convidado_id) do update set
    overall = excluded.overall, golf = excluded.golf, lunch = excluded.lunch,
    organisation = excluded.organisation, presentation = excluded.presentation,
    liked = excluded.liked, improve = excluded.improve, next_year = excluded.next_year,
    updated_at = now();
  return json_build_object('ok', true);
end $$;

grant execute on function public.get_feedback(text) to anon;
grant execute on function public.set_feedback(text,int,int,int,int,int,text,text,text) to anon;

create or replace view public.feedback_resumo as
  select count(*) as respostas,
         round(avg(overall),2) as geral, round(avg(golf),2) as golf,
         round(avg(lunch),2) as almoco, round(avg(organisation),2) as organizacao,
         round(avg(presentation),2) as apresentacao,
         count(*) filter (where next_year='yes') as volta_sim,
         count(*) filter (where next_year='maybe') as volta_talvez,
         count(*) filter (where next_year='no') as volta_nao
  from public.feedback;
