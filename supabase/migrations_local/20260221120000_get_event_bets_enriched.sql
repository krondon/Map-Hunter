-- ==============================================================================
-- MIGRATION: get_event_bets_enriched RPC
-- DATE: 2026-02-21
-- DESCRIPTION: Returns all bets for an event enriched with bettor names and 
--              racer (participant) names. Designed for admin finance panel.
--              Uses SECURITY DEFINER to bypass RLS on bets table.
--
-- NOTE: racer_id stores profiles.id (user UUID), NOT game_players.id.
--       The betting modal uses player.userId as racerId directly.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_event_bets_enriched(p_event_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'bet_id', b.id,
            'user_id', b.user_id,
            'bettor_name', COALESCE(bettor.name, 'Apostador'),
            'bettor_avatar_id', bettor.avatar_id,
            'racer_id', b.racer_id,
            'racer_name', COALESCE(racer.name, 'Participante'),
            'racer_avatar_id', racer.avatar_id,
            'amount', b.amount,
            'created_at', b.created_at
        ) ORDER BY b.created_at DESC
    ), '[]'::jsonb)
    INTO v_result
    FROM public.bets b
    LEFT JOIN public.profiles bettor ON bettor.id = b.user_id
    LEFT JOIN public.profiles racer  ON racer.id  = b.racer_id::uuid
    WHERE b.event_id = p_event_id;

    RETURN v_result;
END;
$$;
