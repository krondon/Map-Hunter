import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 0. Parse optional body for manual trigger
        let isManualAction = false;
        try {
            const body = await req.json();
            if (body && body.trigger === 'manual') {
                isManualAction = true;
                console.log('Manual trigger detected. Bypassing "enabled" check.');
            }
        } catch (e) {
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
        const minPlayers = Number(config.min_players) || 10;
        const maxPlayers = Number(config.max_players) || 30;
        const minGames = Number(config.min_games) || 4;
        const maxGames = Number(config.max_games) || 10;
        const minFee = Number(config.min_fee) || 0;
        const maxFee = Number(config.max_fee) || 100;
        const feeStep = Number(config.fee_step) || 5;

        const playerCount = Math.floor(Math.random() * (maxPlayers - minPlayers + 1)) + minPlayers;
        const gameCount = Math.floor(Math.random() * (maxGames - minGames + 1)) + minGames;

        // Safe fee calculation
        const feeRangeCount = Math.max(0, Math.floor((maxFee - minFee) / feeStep));
        const entryFee = (Math.floor(Math.random() * (feeRangeCount + 1)) * feeStep) + minFee;

        console.log(`Config: Players(${minPlayers}-${maxPlayers}), Games(${minGames}-${maxGames}), Fee(${minFee}-${maxFee} step ${feeStep})`);
        console.log(`Generated: ${playerCount} players, ${gameCount} games, ${entryFee} entry fee`);

        // 3. Selection Strategy (Balanced Difficulty)
        // We define pools based on the logic in clue.dart (dbValue matches camelCase in TypeScript as per enum)
        const easyPool = ['slidingPuzzle', 'ticTacToe', 'imageTrivia', 'trueFalse', 'virusTap', 'flags', 'matchThree', 'fastNumber'];
        const mediumPool = ['hangman', 'wordScramble', 'memorySequence', 'emojiMovie', 'bagShuffle', 'droneDodge', 'missingOperator', 'capitalCities'];
        const hardPool = ['tetris', 'minesweeper', 'snake', 'blockFill', 'codeBreaker', 'holographicPanels', 'primeNetwork', 'percentageCalculation', 'chronologicalOrder', 'drinkMixer', 'librarySort', 'findDifference'];

        const selectedPuzzles: string[] = [];
        const targetEasy = Math.ceil(gameCount * 0.4);
        const targetMedium = Math.ceil(gameCount * 0.4);
        const targetHard = Math.max(0, gameCount - targetEasy - targetMedium);

        console.log(`Generating ${gameCount} minigames: Easy: ${targetEasy}, Medium: ${targetMedium}, Hard: ${targetHard}`);

        const shuffle = (array: string[]) => [...array].sort(() => Math.random() - 0.5);

        selectedPuzzles.push(...shuffle(easyPool).slice(0, targetEasy));
        selectedPuzzles.push(...shuffle(mediumPool).slice(0, targetMedium));
        selectedPuzzles.push(...shuffle(hardPool).slice(0, targetHard));

        // Fill remaining if pools were too small (unlikely but safe)
        while (selectedPuzzles.length < gameCount) {
            selectedPuzzles.push(mediumPool[Math.floor(Math.random() * mediumPool.length)]);
        }

        console.log('Selected Puzzles:', selectedPuzzles);

        // 4. Create Event
        const eventId = crypto.randomUUID();
        const pin = (Math.floor(Math.random() * 900000) + 100000).toString();

        console.log(`Creating event: ${eventId} with PIN: ${pin}`);

        const { data: eventData, error: eventError } = await supabaseClient
            .from('events')
            .insert({
                id: eventId,
                title: `⚡ Competencia Online #${new Date().getTime().toString().slice(-4)}`,
                description: '¡Demuestra tu habilidad!',
                image_url: 'https://m-competitions.supabase.co/storage/v1/object/public/logos/default_event_logo.png', // Placeholder for the new logo
                location_name: 'Online',
                latitude: 0,
                longitude: 0,
                date: new Date().toISOString(),
                max_participants: playerCount,
                pin: pin,
                clue: '🏆 ¡Felicidades! Has completado el circuito online.',
                type: 'online',
                entry_fee: entryFee,
                status: 'active',
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
        })
    }
})
