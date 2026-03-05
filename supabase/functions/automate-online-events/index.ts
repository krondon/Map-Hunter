// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// @ts-ignore: Deno is global in Supabase Edge Functions
serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const supabaseClient = createClient(
            // @ts-ignore
            Deno.env.get('SUPABASE_URL') ?? '',
            // @ts-ignore
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        // 0. Parse optional body for manual trigger
        let isManualAction = false;
        try {
            const body = await req.json();
            if (body && body.trigger === 'manual') {
                isManualAction = true;
                console.log('Manual trigger detected. Bypassing "enabled" check.');
            }
        } catch (_e) {
            // Ignore if no body
        }

        // 1. Fetch Configuration via RPC
        const { data: config, error: configError } = await supabaseClient
            .rpc('get_auto_event_settings');

        if (configError || !config) {
            console.error('Error fetching auto-event settings:', configError);
            return new Response(JSON.stringify({ error: 'Config not found' }), { status: 500 });
        }

        // 2. Check if automation is enabled (Bypass if manual)
        if (config.enabled !== true && !isManualAction) {
            console.log('Automation is disabled and not a manual trigger.');
            return new Response(JSON.stringify({ message: 'Automation disabled' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200
            });
        }

        // 3. Randomize Parameters based on config with robust fallbacks
        const minPlayers = config.min_players !== undefined ? Number(config.min_players) : 5;
        const maxPlayers = config.max_players !== undefined ? Number(config.max_players) : 60;
        const minGames = config.min_games !== undefined ? Number(config.min_games) : 4;
        const maxGames = config.max_games !== undefined ? Number(config.max_games) : 10;
        const minFee = config.min_fee !== undefined ? Number(config.min_fee) : 0;
        const maxFee = config.max_fee !== undefined ? Number(config.max_fee) : 300;
        const feeStep = config.fee_step !== undefined ? Number(config.fee_step) : 5;
        const pendingWaitMinutes = Number(config.pending_wait_minutes) || 5;

        // Usar exactamente el valor máximo configurado por el admin
        const playerCount = maxPlayers;
        const gameCount = Math.floor(Math.random() * (maxGames - minGames + 1)) + minGames;
        const configuredWinners = playerCount < 6 ? 1 : playerCount < 11 ? 2 : 3;

        // Safe fee calculation
        const feeRangeCount = Math.max(0, Math.floor((maxFee - minFee) / feeStep));
        const entryFee = (Math.floor(Math.random() * (feeRangeCount + 1)) * feeStep) + minFee;

        console.log(`Config: Players(${minPlayers}-${maxPlayers}), Games(${minGames}-${maxGames}), Fee(${minFee}-${maxFee} step ${feeStep})`);
        console.log(`Generated: ${playerCount} players, ${gameCount} games, ${entryFee} entry fee`);

        const easyPool = ['slidingPuzzle', 'trueFalse', 'virusTap', 'flags'];
        const mediumPool = ['memorySequence', 'emojiMovie', 'droneDodge', 'missingOperator', 'capitalCities'];
        const hardPool = ['tetris', 'minesweeper', 'blockFill', 'holographicPanels', 'percentageCalculation', 'drinkMixer'];

        const selectedPuzzles: string[] = [];
        const targetEasy = Math.min(easyPool.length, Math.ceil(gameCount * 0.4));
        const targetMedium = Math.min(mediumPool.length, Math.ceil(gameCount * 0.4));
        const targetHard = Math.min(hardPool.length, gameCount - targetEasy - targetMedium);

        console.log(`Generating ${gameCount} minigames: Easy: ${targetEasy}, Medium: ${targetMedium}, Hard: ${targetHard}`);

        const shuffle = (array: string[]) => [...array].sort(() => Math.random() - 0.5);

        const shuffledEasy = shuffle(easyPool);
        const shuffledMedium = shuffle(mediumPool);
        const shuffledHard = shuffle(hardPool);

        selectedPuzzles.push(...shuffledEasy.slice(0, targetEasy));
        selectedPuzzles.push(...shuffledMedium.slice(0, targetMedium));
        selectedPuzzles.push(...shuffledHard.slice(0, targetHard));

        // Extraer los juegos que sobraron para rellenar huecos sin repetir
        const unusedGames = [
            ...shuffledEasy.slice(targetEasy),
            ...shuffledMedium.slice(targetMedium),
            ...shuffledHard.slice(targetHard)
        ];

        const remainingToFill = gameCount - selectedPuzzles.length;
        if (remainingToFill > 0) {
            selectedPuzzles.push(...shuffle(unusedGames).slice(0, remainingToFill));
        }

        // Si piden más juegos del total disponible, repetir pero sin que salgan pegados y de manera variada
        while (selectedPuzzles.length < gameCount) {
            const allGames = [...easyPool, ...mediumPool, ...hardPool];
            const candidate = allGames[Math.floor(Math.random() * allGames.length)];
            if (selectedPuzzles[selectedPuzzles.length - 1] !== candidate) {
                selectedPuzzles.push(candidate);
            }
        }

        console.log('Selected Puzzles:', selectedPuzzles);

        // 4. Create Event
        // @ts-ignore
        const eventId = crypto.randomUUID();
        const pin = (Math.floor(Math.random() * 900000) + 100000).toString();

        console.log(`Creating event: ${eventId} with PIN: ${pin}`);

        const { data: _eventData, error: eventError } = await supabaseClient
            .from('events')
            .insert({
                id: eventId,
                title: `⚡ Competencia Online #${new Date().getTime().toString().slice(-4)}`,
                description: '¡Demuestra tu habilidad!',
                image_url: 'https://shxbfwdapwbizxspicai.supabase.co/storage/v1/object/public/logos/default_event_logo.png',
                location_name: 'Online',
                latitude: 0,
                longitude: 0,
                // date = now + pendingWaitMinutes (countdown shown in EventWaitingScreen)
                date: new Date(Date.now() + pendingWaitMinutes * 60 * 1000).toISOString(),
                max_participants: playerCount,
                pin: pin,
                clue: '🏆 ¡Felicidades! Has completado el circuito online.',
                type: 'online',
                entry_fee: entryFee,
                status: 'pending',   // ← starts pending; activated by auto_start_online_event RPC
                configured_winners: configuredWinners,
                created_at: new Date().toISOString()
            })
            .select()
            .single();

        if (eventError) {
            console.error('Error creating event:', eventError);
            throw eventError;
        }

        // 5. Create Clues (Minigames)
        const clues = selectedPuzzles.map((puzzle, index) => ({
            event_id: eventId,
            title: `Minijuego ${index + 1}`,
            description: 'Supera el desafío para avanzar',
            type: 'minigame',
            puzzle_type: puzzle,
            riddle_question: '¡Gana para completar!',
            riddle_answer: 'WIN',
            xp_reward: 50,
            hint: 'Pista Online',
            sequence_index: index + 1,
            latitude: 0,
            longitude: 0
        }));

        console.log(`Inserting ${clues.length} clues for event ${eventId}...`);

        const { data: savedClues, error: cluesError } = await supabaseClient
            .from('clues')
            .insert(clues)
            .select();

        if (cluesError) {
            console.error('❌ Error creating clues:', JSON.stringify(cluesError));
            throw cluesError;
        }

        console.log(`✅ Successfully saved ${savedClues?.length || 0} clues.`);

        // 6. Create Store with consistent prices
        const storeProducts = [
            { id: 'black_screen', cost: 75 },
            { id: 'blur_screen', cost: 75 },
            { id: 'extra_life', cost: 40 },
            { id: 'return', cost: 90 },
            { id: 'freeze', cost: 120 },
            { id: 'shield', cost: 40 },
            { id: 'life_steal', cost: 120 },
            { id: 'invisibility', cost: 40 }
        ];

        console.log(`Creating mall store for event ${eventId}...`);

        const { data: savedStore, error: storeError } = await supabaseClient
            .from('mall_stores')
            .insert({
                event_id: eventId,
                name: 'Tienda de Objetos',
                description: 'Potenciadores para la competencia',
                qr_code_data: `store_${eventId}`,
                products: storeProducts
            })
            .select()
            .single();

        if (storeError) {
            console.error('❌ Error creating mall store:', JSON.stringify(storeError));
            throw storeError;
        }

        console.log('✅ Store created successfully:', savedStore.id);

        return new Response(JSON.stringify({
            success: true,
            eventId,
            pin,
            games: selectedPuzzles,
            cluesSaved: savedClues?.length || 0,
            storeId: savedStore.id
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        });

    } catch (error: any) {
        console.error('Automation error:', error.message);
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        });
    }
});
