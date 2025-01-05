module briscola::single_player_briscola {
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::event::{Self};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};


    /*===================CONSTANTS========================*/


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


    /*===================GAME STATUSES========================*/
    const GAME_STATUS_ACTIVE: u8 = 0;
    const GAME_STATUS_FINISHED: u8 = 1;
    const GAME_STATUS_DRAW: u8 = 2;

    const INITIAL_CARDS_PER_PLAYER: u8 = 3;

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
}