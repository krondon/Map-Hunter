
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY
);

async function verify() {
    console.log('Fetching latest online event...');
    const { data: events, error: eventError } = await supabase
        .from('events')
        .select('*')
        .eq('type', 'online')
        .order('created_at', { ascending: false })
        .limit(1);

    if (eventError) {
        console.error('Error fetching event:', eventError);
        return;
    }

    if (!events || events.length === 0) {
        console.log('No online events found.');
        return;
    }

    const event = events[0];
    console.log('Event Found:', {
        id: event.id,
        title: event.title,
        clue: event.clue,
        status: event.status
    });

    console.log('\nFetching clues for event...');
    const { data: clues, error: cluesError } = await supabase
        .from('clues')
        .select('*')
        .eq('event_id', event.id)
        .order('sequence_index', { ascending: true });

    if (cluesError) {
        console.error('Error fetching clues:', cluesError);
    } else {
        console.log(`Found ${clues.length} clues.`);
        clues.forEach((c, i) => {
            console.log(`  ${i + 1}. [${c.puzzle_type}] ${c.title}`);
        });
    }

    console.log('\nFetching mall store for event...');
    const { data: stores, error: storesError } = await supabase
        .from('mall_stores')
        .select('*')
        .eq('event_id', event.id);

    if (storesError) {
        console.error('Error fetching stores:', storesError);
    } else if (stores && stores.length > 0) {
        const store = stores[0];
        console.log('Store Found:', {
            name: store.name,
            qr: store.qr_code_data,
            productCount: Array.isArray(store.products) ? store.products.length : (typeof store.products === 'string' ? JSON.parse(store.products).length : 0)
        });
        console.log('Products:', store.products);
    } else {
        console.log('No store found for this event.');
    }
}

verify();
