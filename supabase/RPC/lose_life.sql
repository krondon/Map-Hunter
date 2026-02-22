
DECLARE
    current_lives integer;
    new_lives integer;
BEGIN
    -- Select with locking
    SELECT lives INTO current_lives
    FROM public.game_players
    WHERE event_id = p_event_id AND user_id = p_user_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Player not found (Event: %, User: %)', p_event_id, p_user_id;
    END IF;
    IF current_lives > 0 THEN
        new_lives := current_lives - 1;
    ELSE
        new_lives := 0;
    END IF;
    UPDATE public.game_players
    SET lives = new_lives,
        updated_at = now()
    WHERE event_id = p_event_id AND user_id = p_user_id;
    RETURN new_lives;
END;
