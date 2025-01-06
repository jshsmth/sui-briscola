module briscola::single_player_briscola {
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::event::{Self};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};

    /*===================SUITS========================*/
    const COINS: vector<u8> = b"Coins";
    const CUPS: vector<u8> = b"Cups";
    const SWORDS: vector<u8> = b"Swords";
    const CLUBS: vector<u8> = b"Clubs";

    /*===================RANKS========================*/
    const ACE: vector<u8> = b"Ace";
    const TWO: vector<u8> = b"2";
    const THREE: vector<u8> = b"3";
    const FOUR: vector<u8> = b"4";
    const FIVE: vector<u8> = b"5";
    const SIX: vector<u8> = b"6";
    const SEVEN: vector<u8> = b"7";
    const JACK: vector<u8> = b"Jack";
    const KNIGHT: vector<u8> = b"Knight";
    const KING: vector<u8> = b"King";

    /*===================GAME STATUSES================*/
    const GAME_STATUS_ACTIVE: u8 = 0;
    const GAME_STATUS_FINISHED: u8 = 1;
    const GAME_STATUS_DRAW: u8 = 2;

    const INITIAL_CARDS_PER_PLAYER: u8 = 3;

    /*===================ERRORS========================*/
    const EInvalidCard: u64 = 1;
    const ENotPlayerTurn: u64 = 2;

    /*===================STRUCTS========================*/
    public struct Card has store, copy, drop {
        suit: String,
        rank: String,
        points: u8,
    }

    public struct Game has key, store {
        id: UID,
        deck: vector<Card>,
        player_hand: vector<Card>,
        house_hand: vector<Card>,
        player: address,
        status: u8,
        player_score: u8,
        house_score: u8,
        trump_card: Card,
        current_player: address,
        pending_house_card: Option<PendingHouseCard>,
    }

    /*===================EVENTS========================*/
    public struct GameCreatedEvent has copy, drop {
        game_id: ID,
    }

    public struct GameInitializedDetails has copy, drop {
        trump_card: Card,
        player_hand: vector<Card>,
        house_hand: vector<Card>,
        remaining_deck: vector<Card>,
    }

    public struct CardPlayedEvent has copy, drop {
        player_card: Card,
        house_card: Card,
        winner: address,
        points: u8,
    }

    public struct HandCompletedEvent has copy, drop {
        player_score: u8,
        house_score: u8,
        cards_remaining: u64,
    }

    public struct GameOverEvent has copy, drop {
        final_player_score: u8,
        final_house_score: u8,
        winner: address,
    }

    public struct GameDrawEvent has copy, drop {
        final_player_score: u8,
        final_house_score: u8,
    }

    public struct HousePlayedFirstEvent has copy, drop {
        house_card: Card,
    }

    public struct PendingHouseCard has store, drop {
        card: Card
    }

    /*===================INIT========================*/
    fun init(_ctx: &mut TxContext) {
        // Module initialization logic can go here if needed
    }


    /*===================CREATE DECK========================*/
    public fun createDeck(): vector<Card> {
        let mut deck = vector::empty();
        
        // Add cards for each suit
        addSuitCards(&mut deck, string::utf8(COINS));
        addSuitCards(&mut deck, string::utf8(CUPS));
        addSuitCards(&mut deck, string::utf8(SWORDS));
        addSuitCards(&mut deck, string::utf8(CLUBS));
        
        deck
    }

    /*===================ADD SUIT CARDS========================*/
    fun addSuitCards(deck: &mut vector<Card>, suit: String) {
        // Add Ace
        vector::push_back(deck, Card { 
            suit: copy suit, 
            rank: string::utf8(ACE), 
            points: 11 
        });
        
        // Add number cards 2-7
        vector::push_back(deck, Card { suit: copy suit, rank: string::utf8(TWO), points: 0 });
        vector::push_back(deck, Card { suit: copy suit, rank: string::utf8(THREE), points: 10 });
        vector::push_back(deck, Card { suit: copy suit, rank: string::utf8(FOUR), points: 0 });
        vector::push_back(deck, Card { suit: copy suit, rank: string::utf8(FIVE), points: 0 });
        vector::push_back(deck, Card { suit: copy suit, rank: string::utf8(SIX), points: 0 });
        vector::push_back(deck, Card { suit: copy suit, rank: string::utf8(SEVEN), points: 0 });
        
        // Add face cards
        vector::push_back(deck, Card { suit: copy suit, rank: string::utf8(JACK), points: 2 });
        vector::push_back(deck, Card { suit: copy suit, rank: string::utf8(KNIGHT), points: 3 });
        vector::push_back(deck, Card { suit: copy suit, rank: string::utf8(KING), points: 4 });
    }



    /*===================SHUFFLE DECK========================*/
    public fun simpleShuffleDeck(deck: &mut vector<Card>, ctx: &mut TxContext) {
        let length = vector::length(deck);
        let mut i = length;
        
        while (i > 1) {
            i = i - 1;
            // Use transaction context for pseudo-randomness
            let random_index = (tx_context::epoch(ctx) + i as u64) % (i as u64);
            vector::swap(deck, i, (random_index as u64));
        };
    }

    /*===================CREATE GAME========================*/
    public entry fun createGame(ctx: &mut TxContext) {
        let mut deck = createDeck();
        simpleShuffleDeck(&mut deck, ctx);

        let trump_card = vector::pop_back(&mut deck);  // Remove trump card first
        
        let mut game = Game {
            id: object::new(ctx),
            deck,
            player_hand: vector::empty(),
            house_hand: vector::empty(),
            player: tx_context::sender(ctx),
            status: GAME_STATUS_ACTIVE,
            player_score: 0,
            house_score: 0,
            trump_card,
            current_player: tx_context::sender(ctx),
            pending_house_card: option::none(),
        };

        // Deal initial cards to player and house
        let mut i = 0;
        while (i < INITIAL_CARDS_PER_PLAYER) {
            vector::push_back(&mut game.player_hand, vector::pop_back(&mut game.deck));
            vector::push_back(&mut game.house_hand, vector::pop_back(&mut game.deck));
            i = i + 1;
        };

        // Emit the game created event
        event::emit(GameCreatedEvent {
            game_id: object::uid_to_inner(&game.id)
        });

        // JUST FOR DEBUGGING PURPOSES FOR NOW
        event::emit(GameInitializedDetails {
            trump_card: copy game.trump_card,
            player_hand: copy game.player_hand,
            house_hand: copy game.house_hand,
            remaining_deck: copy game.deck,
        });

        // Transfer the game object to the starting player
        transfer::transfer(game, tx_context::sender(ctx));
    }


/*=================== CHECK HOUSE PLAY ========================*/

public entry fun checkHousePlay(game: &mut Game, ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);
    
    // Verify it's player's turn
    assert!(game.player == sender, ENotPlayerTurn);
    
    if (game.current_player == @0x0) {
        // House plays first
        let house_card = vector::remove(&mut game.house_hand, 0);
        
        // Store the house card and emit event
        game.pending_house_card = option::some(PendingHouseCard { card: house_card });
        
        event::emit(HousePlayedFirstEvent {
            house_card,
        });
    };
}

/*=================== PLAY CARD ========================*/

public entry fun playCard(game: &mut Game, player_card_index: u64, ctx: &mut TxContext) {
    // Check if game is already finished
    if (game.status == GAME_STATUS_FINISHED) {
        let winner = if (game.player_score > game.house_score) {
            game.player
        } else {
            @0x0
        };
        
        event::emit(GameOverEvent {
            final_player_score: game.player_score,
            final_house_score: game.house_score,
            winner
        });
        return
    };

    let sender = tx_context::sender(ctx);
    let total_points;
    let house_card;
    let player_card;   
    
    // Verify it's player's turn
    assert!(game.player == sender, ENotPlayerTurn);
    
    if (option::is_some(&game.pending_house_card)) {
        // House has already played
        assert!(player_card_index < vector::length(&game.player_hand), EInvalidCard);
        player_card = vector::remove(&mut game.player_hand, player_card_index);
        
        let pending = option::extract(&mut game.pending_house_card);
        house_card = pending.card;
        
        // Determine winner and calculate points
        total_points = getCardValue(&player_card) + getCardValue(&house_card);
        let winner_address = determineWinner(&player_card, &house_card, &game.trump_card, game.player);
        
        // Update scores and set next player
        if (winner_address == game.player) {
            game.player_score = game.player_score + total_points;
        } else {
            game.house_score = game.house_score + total_points;
        };
        
        game.current_player = winner_address;
        
    } else {
        // Player plays first
        assert!(player_card_index < vector::length(&game.player_hand), EInvalidCard);
        player_card = vector::remove(&mut game.player_hand, player_card_index);
        
        // House responds
        house_card = vector::remove(&mut game.house_hand, 0);
        
        // Determine winner and calculate points
        total_points = getCardValue(&player_card) + getCardValue(&house_card);
        let winner_address = determineWinner(&player_card, &house_card, &game.trump_card, game.player);
        
        // Update scores and set next player
        if (winner_address == game.player) {
            game.player_score = game.player_score + total_points;
        } else {
            game.house_score = game.house_score + total_points;
        };
        
        // Set who plays first in next round
        game.current_player = winner_address;
    };

    // Draw cards logic
    if (!vector::is_empty(&game.deck)) {
        if (vector::length(&game.deck) == 1) {
            // Only one card left, give it to the winner
            if (game.current_player == game.player) {
                vector::push_back(&mut game.player_hand, vector::pop_back(&mut game.deck));
            } else {
                vector::push_back(&mut game.house_hand, vector::pop_back(&mut game.deck));
            };
        } else {
            // Normal case - enough cards for both players
            if (game.current_player == game.player) {
                // Winner (player) draws first
                vector::push_back(&mut game.player_hand, vector::pop_back(&mut game.deck));
                vector::push_back(&mut game.house_hand, vector::pop_back(&mut game.deck));
            } else {
                // Winner (house) draws first
                vector::push_back(&mut game.house_hand, vector::pop_back(&mut game.deck));
                vector::push_back(&mut game.player_hand, vector::pop_back(&mut game.deck));
            };
        };
    };


    event::emit(CardPlayedEvent {
        player_card,
        house_card,
        winner: game.current_player,
        points: total_points,
    });

    event::emit(HandCompletedEvent {
        player_score: game.player_score,
        house_score: game.house_score,
        cards_remaining: vector::length(&game.deck),
    });

    // Check if game is over (no cards left in hands AND deck)
    if (vector::is_empty(&game.deck) && 
        (vector::is_empty(&game.player_hand) || vector::is_empty(&game.house_hand))) {
        
        if (game.player_score == game.house_score) {
            game.status = GAME_STATUS_DRAW;
            event::emit(GameDrawEvent {
                final_player_score: game.player_score,
                final_house_score: game.house_score,
            });
        } else {
            game.status = GAME_STATUS_FINISHED;
            let final_winner = if (game.player_score > game.house_score) {
                game.player
            } else {
                @0x0 // house address
            };
            
            event::emit(GameOverEvent {
                final_player_score: game.player_score,
                final_house_score: game.house_score,
                winner: final_winner
            });
        };
    };
}

fun determineWinner(player_card: &Card, house_card: &Card, trump_card: &Card, player_address: address): address {
    let house_address = @0x0; // Using 0x0 as house address

    // If both cards are the same suit
    if (string::as_bytes(&player_card.suit) == string::as_bytes(&house_card.suit)) {
        if (getCardValue(player_card) > getCardValue(house_card)) {
            return player_address
        } else {
            return house_address
        }
    };

    // If one card is trump suit
    if (string::as_bytes(&player_card.suit) == string::as_bytes(&trump_card.suit)) {
        return player_address
    };
    if (string::as_bytes(&house_card.suit) == string::as_bytes(&trump_card.suit)) {
        return house_address
    };

    house_address
}

/*=================== HELPER FUNCTIONS ========================*/

fun getCardValue(card: &Card): u8 {
    let rank_bytes = string::as_bytes(&card.rank);
    let ace_bytes = ACE;
    let three_bytes = THREE; 
    let king_bytes = KING;
    let knight_bytes = KNIGHT;
    let jack_bytes = JACK;

    if (rank_bytes == &ace_bytes) {
        return 11
    };
    if (rank_bytes == &three_bytes) {
        return 10
    };
    if (rank_bytes == &king_bytes) {
        return 4
    };
    if (rank_bytes == &knight_bytes) {
        return 3
    };
    if (rank_bytes == &jack_bytes) {
        return 2
    };
    0
}
}