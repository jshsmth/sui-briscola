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

    #[test]
    fun test_check_house_play() {
        let mut scenario = test_scenario::begin(PLAYER);
        let test = &mut scenario;
        
        test_scenario::next_tx(test, PLAYER);
        {
            single_player_briscola::createGame(test_scenario::ctx(test));
        };

        // Check house play when it's house's turn
        test_scenario::next_tx(test, PLAYER);
        {
            let mut game = test_scenario::take_from_sender<Game>(test);
            
            // Set current_player to @0x0 to simulate house's turn
            single_player_briscola::setCurrentPlayer(&mut game, @0x0);
            
            // Call checkHousePlay
            single_player_briscola::checkHousePlay(&mut game, test_scenario::ctx(test));
            
            // Verify that pending_house_card is set
            assert!(single_player_briscola::hasPendingHouseCard(&game), 11);
            
            // Verify house hand size decreased by 1
            assert!(single_player_briscola::getHouseHandSize(&game) == 2, 12);
            
            test_scenario::return_to_sender(test, game);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_play_card() {
        let mut scenario = test_scenario::begin(PLAYER);
        let test = &mut scenario;
        
        test_scenario::next_tx(test, PLAYER);
        {
            single_player_briscola::createGame(test_scenario::ctx(test));
        };

        // Test player playing first
        test_scenario::next_tx(test, PLAYER);
        {
            let mut game = test_scenario::take_from_sender<Game>(test);
            
            // Player plays first card (index 0)
            single_player_briscola::playCard(&mut game, 0, test_scenario::ctx(test));
            
            // Verify hand sizes decreased
            assert!(single_player_briscola::getPlayerHandSize(&game) == 3, 13);
            assert!(single_player_briscola::getHouseHandSize(&game) == 3, 14); 
            
            // Verify deck size decreased by 2 (due to drawing)
            assert!(single_player_briscola::getDeckSize(&game) == 31, 15);
            
            test_scenario::return_to_sender(test, game);
        };

        // Test house playing first
        test_scenario::next_tx(test, PLAYER);
        {
            let mut game = test_scenario::take_from_sender<Game>(test);
            
            // Set current_player to house
            single_player_briscola::setCurrentPlayer(&mut game, @0x0);
            
            // House plays first
            single_player_briscola::checkHousePlay(&mut game, test_scenario::ctx(test));
            
            // Verify house played a card
            assert!(single_player_briscola::hasPendingHouseCard(&game), 16);
            assert!(single_player_briscola::getHouseHandSize(&game) == 2, 17);
            
            // Player responds
            single_player_briscola::playCard(&mut game, 0, test_scenario::ctx(test));
            
            // Verify hand sizes after drawing
            assert!(single_player_briscola::getPlayerHandSize(&game) == 3, 18);
            assert!(single_player_briscola::getHouseHandSize(&game) == 3, 19);
            
            // Verify deck size decreased by 2
            assert!(single_player_briscola::getDeckSize(&game) == 29, 20);
            
            test_scenario::return_to_sender(test, game);
        };
        
        test_scenario::end(scenario);
    }
}
