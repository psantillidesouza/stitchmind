-- Troca o envio "a cada 4h" por horários otimizados para os EUA.
-- Pesquisa (PushEngage/Iterable/MoEngage 2026) p/ apps de lifestyle/hobby:
-- manhã, almoço, fim de tarde e NOITE (auge p/ relaxar e fazer crochê).
-- Âncora: America/New_York (Eastern — maior bloco populacional dos EUA).
-- 4 envios/dia, todos sorteando do pool de 100 mensagens. ATIVOS.

-- 1) Remove o agendamento de intervalo (a cada 4h) criado na 023.
DELETE FROM scheduled_notifications
WHERE schedule_kind = 'interval' AND interval_minutes = 240 AND use_pool = true;

-- 2) Cria 4 agendamentos diários nos melhores horários (ET):
--    10:00 (manhã), 13:00 (almoço), 18:00 (fim de tarde), 21:00 (noite/auge).
--    next_run_at = próxima ocorrência do horário no fuso (corrige DST sozinho).
INSERT INTO scheduled_notifications
  (use_pool, target_type, schedule_kind, time_of_day, timezone, enabled, next_run_at)
SELECT
  true, 'all', 'daily', to_char(h, 'FM00') || ':00', 'America/New_York', true,
  CASE WHEN cand > now() THEN cand ELSE cand + interval '1 day' END
FROM (
  SELECT h,
    (date_trunc('day', now() AT TIME ZONE 'America/New_York') + make_interval(hours => h))
      AT TIME ZONE 'America/New_York' AS cand
  FROM (VALUES (10), (13), (18), (21)) AS t(h)
) s;
