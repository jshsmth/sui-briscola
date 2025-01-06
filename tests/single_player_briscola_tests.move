#[test_only]
module briscola::briscola_tests {
    use sui::test_scenario::{Self};
    use briscola::single_player_briscola::{Self, Game};
    use std::string;

    const PLAYER: address = @0xA;

    #[test]
    fun test_create_game() {
        let mut scenario =  test_scenario::begin(PLAYER);
        let test = &mut scenario;
        
        // Start the game as PLAYER
        test_scenario::next_tx(test, PLAYER);
        {
            single_player_briscola::createGame(test_scenario::ctx(test));
        };

        // Verify the game was created and transferred to PLAYER
        test_scenario::next_tx(test, PLAYER);
        {
            let game = test_scenario::take_from_sender<Game>(test);
            
            assert!(single_player_briscola::getDeckSize(&game) == 33, 6);
            assert!(single_player_briscola::getPlayerHandSize(&game) == 3, 7);
            assert!(single_player_briscola::getHouseHandSize(&game) == 3, 8);
            let trump_card = single_player_briscola::getTrumpCard(&game);
            assert!(!string::is_empty(&single_player_briscola::getCardSuit(&trump_card)), 9);
            assert!(!string::is_empty(&single_player_briscola::getCardRank(&trump_card)), 10);
            
            
            test_scenario::return_to_sender(test, game);
        };
        
        test_scenario::end(scenario);
    }
}
