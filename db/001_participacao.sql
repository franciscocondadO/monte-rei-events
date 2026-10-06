alter table public.convidados
  add column if not exists joga boolean,
  add column if not exists ac_nome text,
  add column if not exists ac_joga boolean not null default false,
  add column if not exists ac_handicap numeric(4,1),
  drop column if exists licenca;

delete from public.config where chave = 'limite_inscricoes';
insert into public.config(chave, valor) values ('limite_jogadores','60'), ('limite_almoco','100')
  on conflict do nothing;

drop function if exists public.set_rsvp(text, boolean, text, numeric, text, text);
drop function if exists public.get_convidado(text);

create or replace function public.get_convidado(p_token text)
returns json language sql security definer set search_path to 'public' as $$
  select json_build_object(
    'nome', nome, 'idioma', idioma, 'rsvp', rsvp, 'joga', joga,
    'nome_confirmado', nome_confirmado, 'handicap', handicap,
    'pedido_grupo', pedido_grupo, 'ac_nome', ac_nome, 'ac_joga', ac_joga,
    'ac_handicap', ac_handicap, 'saida_hora', saida_hora
  ) from public.convidados where token = p_token;
$$;

create or replace function public.set_rsvp(
  p_token text, p_participacao text, p_nome text, p_handicap numeric,
  p_pedido_grupo text, p_ac_nome text, p_ac_joga boolean, p_ac_handicap numeric)
returns json language plpgsql security definer set search_path to 'public' as $$
declare
  v_lim_j int; v_lim_a int; v_jog int; v_alm int;
  v_joga boolean; v_ac text; v_acj boolean; v_novo text;
  v_meus_j int; v_meus_a int; v_atual text;
begin
  select rsvp into v_atual from public.convidados where token = p_token for update;
  if v_atual is null then return json_build_object('ok', false, 'erro', 'token_invalido'); end if;
  if p_participacao not in ('joga','presente','nao') then
    return json_build_object('ok', false, 'erro', 'participacao_invalida');
  end if;

  select valor::int into v_lim_j from public.config where chave = 'limite_jogadores';
  select valor::int into v_lim_a from public.config where chave = 'limite_almoco';

  v_joga := (p_participacao = 'joga');
  v_ac := case when p_participacao = 'nao' then null else nullif(trim(p_ac_nome),'') end;
  v_acj := (v_ac is not null and coalesce(p_ac_joga, false));

  if p_participacao = 'nao' then
    v_novo := 'nao';
  else
    select coalesce(sum(coalesce(joga,false)::int + ac_joga::int),0),
           coalesce(sum(1 + (ac_nome is not null)::int),0)
      into v_jog, v_alm
      from public.convidados where rsvp = 'sim' and token <> p_token;
    v_meus_j := v_joga::int + v_acj::int;
    v_meus_a := 1 + (v_ac is not null)::int;
    if v_jog + v_meus_j > v_lim_j or v_alm + v_meus_a > v_lim_a then
      v_novo := 'lista_espera';
    else
      v_novo := 'sim';
    end if;
  end if;

  update public.convidados set
    rsvp = v_novo,
    joga = case when p_participacao = 'nao' then null else v_joga end,
    nome_confirmado = case when p_participacao <> 'nao' then nullif(trim(p_nome),'') end,
    handicap = case when v_joga then p_handicap end,
    pedido_grupo = case when v_joga then nullif(trim(p_pedido_grupo),'') end,
    ac_nome = v_ac,
    ac_joga = v_acj,
    ac_handicap = case when v_acj then p_ac_handicap end,
    respondido_at = now()
  where token = p_token;

  return json_build_object('ok', true, 'rsvp', v_novo);
end $$;

grant execute on function public.get_convidado(text) to anon;
grant execute on function public.set_rsvp(text,text,text,numeric,text,text,boolean,numeric) to anon;

create or replace view public.painel as
  select tipo, rsvp, count(*) as total,
         sum(coalesce(joga,false)::int + ac_joga::int) filter (where rsvp='sim') as jogadores,
         sum(1 + (ac_nome is not null)::int) filter (where rsvp='sim') as almoco
  from public.convidados group by tipo, rsvp;
