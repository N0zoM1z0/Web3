// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./WinningToken.sol";

/**
 * @title Rock Paper Scissors Game
 * @notice A fair implementation of Rock Paper Scissors on Ethereum
 * @dev Players commit hashed moves, then reveal them to determine the winner
 */
contract RockPaperScissors {
    // Game moves
    enum Move {
        None,
        Rock,
        Paper,
        Scissors
    }

    // Game states
    enum GameState {
        Created,
        Committed,
        Revealed,
        Finished,
        Cancelled
    }

    // Game structure
    struct Game {
        address playerA; // Creator of the game
        address playerB; // Second player to join
        uint256 bet; // Amount of ETH bet
        uint256 timeoutInterval; // Time allowed for reveal phase
        uint256 revealDeadline; // Deadline for revealing moves
        uint256 creationTime; // When the game was created
        uint256 joinDeadline; // Deadline for someone to join the game
        uint256 totalTurns; // Total number of turns in the game
        uint256 currentTurn; // Current turn number
        bytes32 commitA; // Hashed move from player A
        bytes32 commitB; // Hashed move from player B
        Move moveA; // Revealed move from player A
        Move moveB; // Revealed move from player B
        uint8 scoreA; // Score for player A
        uint8 scoreB; // Score for player B
        GameState state; // Current state of the game
    }

    // Mapping of game ID to game data
    mapping(uint256 => Game) public games;

    // Counter for game IDs
    uint256 public gameCounter;

    // Token for winners
    WinningToken public immutable winningToken;

    // Admin address for ownership functions
    address public adminAddress;

    // Deposit amounts and timeouts
    uint256 public constant minBet = 0.01 ether;
    uint256 public joinTimeout = 24 hours; // Time allowed for someone to join the game

    // Protocol fee percentage (10%)
    uint256 public constant PROTOCOL_FEE_PERCENT = 10;

    // Accumulated fees that the admin can withdraw
    uint256 public accumulatedFees;

    // Events
    event GameCreated(uint256 indexed gameId, address indexed creator, uint256 bet, uint256 totalTurns);
    event PlayerJoined(uint256 indexed gameId, address indexed player);
    event MoveCommitted(uint256 indexed gameId, address indexed player, uint256 currentTurn);
    event MoveRevealed(uint256 indexed gameId, address indexed player, Move move, uint256 currentTurn);
    event TurnCompleted(uint256 indexed gameId, address winner, uint256 currentTurn);
    event GameFinished(uint256 indexed gameId, address winner, uint256 prize);
    event GameCancelled(uint256 indexed gameId);
    event JoinTimeoutUpdated(uint256 oldTimeout, uint256 newTimeout);
    event FeeCollected(uint256 gameId, uint256 feeAmount);
    event FeeWithdrawn(address indexed admin, uint256 amount);

    /**
     * @dev Constructor sets up the winning token and admin
     */
    constructor() {
        winningToken = new WinningToken();
        adminAddress = msg.sender;
    }

    /**
     * @notice Create a new game with ETH bet
     * @param _totalTurns Number of turns for the game (must be odd)
     * @param _timeoutInterval Seconds allowed for reveal phase
     */
    function createGameWithEth(uint256 _totalTurns, uint256 _timeoutInterval) external payable returns (uint256) {
        require(msg.value >= minBet, "Bet amount too small");
        require(_totalTurns > 0, "Must have at least one turn");
        require(_totalTurns % 2 == 1, "Total turns must be odd");
        require(_timeoutInterval >= 5 minutes, "Timeout must be at least 5 minutes");

        uint256 gameId = gameCounter++;

        Game storage game = games[gameId];
        game.playerA = msg.sender;
        game.bet = msg.value;
        game.timeoutInterval = _timeoutInterval;
        game.creationTime = block.timestamp;
        game.joinDeadline = block.timestamp + joinTimeout;
        game.totalTurns = _totalTurns;
        game.currentTurn = 1;
        game.state = GameState.Created;

        emit GameCreated(gameId, msg.sender, msg.value, _totalTurns);

        return gameId;
    }

    /**
     * @notice Create a new game with winning token
     * @param _totalTurns Number of turns for the game (must be odd)
     * @param _timeoutInterval Seconds allowed for reveal phase
     */
    function createGameWithToken(uint256 _totalTurns, uint256 _timeoutInterval) external returns (uint256) {
        require(winningToken.balanceOf(msg.sender) >= 1, "Must have winning token");
        require(_totalTurns > 0, "Must have at least one turn");
        require(_totalTurns % 2 == 1, "Total turns must be odd");
        require(_timeoutInterval >= 5 minutes, "Timeout must be at least 5 minutes");

        // Transfer token to contract
        winningToken.transferFrom(msg.sender, address(this), 1); // 重入？

        uint256 gameId = gameCounter++;

        Game storage game = games[gameId];
        game.playerA = msg.sender;
        game.bet = 0; // Zero ether bet because using token
        game.timeoutInterval = _timeoutInterval;
        game.creationTime = block.timestamp;
        game.joinDeadline = block.timestamp + joinTimeout;
        game.totalTurns = _totalTurns;
        game.currentTurn = 1;
        game.state = GameState.Created;

        emit GameCreated(gameId, msg.sender, 0, _totalTurns);

        return gameId;
    }

    /**
     * @notice Join an existing game with ETH bet
     * @param _gameId ID of the game to join
     */
    function joinGameWithEth(uint256 _gameId) external payable {
        Game storage game = games[_gameId];

        require(game.state == GameState.Created, "Game not open to join");
        require(game.playerA != msg.sender, "Cannot join your own game");
        require(block.timestamp <= game.joinDeadline, "Join deadline passed");
        require(msg.value == game.bet, "Bet amount must match creator's bet");

        game.playerB = msg.sender; // 这里playerB加入后没有更新游戏状态为已加入，也就是说我们仍可以加入重置game.playerB
        emit PlayerJoined(_gameId, msg.sender);
    }

    /**
     * @notice Join an existing game with token
     * @param _gameId ID of the game to join
     */
    function joinGameWithToken(uint256 _gameId) external {
        Game storage game = games[_gameId];

        require(game.state == GameState.Created, "Game not open to join");
        require(game.playerA != msg.sender, "Cannot join your own game");
        require(block.timestamp <= game.joinDeadline, "Join deadline passed");
        require(game.bet == 0, "This game requires ETH bet");
        require(winningToken.balanceOf(msg.sender) >= 1, "Must have winning token");

        // Transfer token to contract
        winningToken.transferFrom(msg.sender, address(this), 1); // 重入？

        game.playerB = msg.sender; // 同joinGameWithEth的问题，感觉应该需要更新game的status防止多次加入
        emit PlayerJoined(_gameId, msg.sender);
    }

    /**
     * @notice Commit a hashed move (keccak256(move + salt))
     * @param _gameId ID of the game
     * @param _commitHash Hashed move with salt
     */
    function commitMove(uint256 _gameId, bytes32 _commitHash) external {
        Game storage game = games[_gameId];

        require(msg.sender == game.playerA || msg.sender == game.playerB, "Not a player in this game");
        require(game.state == GameState.Created || game.state == GameState.Committed, "Game not in commit phase");

        if (game.currentTurn == 1 && game.commitA == bytes32(0) && game.commitB == bytes32(0)) {
            // First turn, first commits
            require(game.playerB != address(0), "Waiting for player B to join");
            game.state = GameState.Committed;
        } else {
            // Later turns or second player committing
            require(game.state == GameState.Committed, "Not in commit phase");
            require(game.moveA == Move.None && game.moveB == Move.None, "Moves already committed for this turn");
        }

        if (msg.sender == game.playerA) {
            require(game.commitA == bytes32(0), "Already committed");
            game.commitA = _commitHash;
        } else {
            require(game.commitB == bytes32(0), "Already committed");
            game.commitB = _commitHash;
        }

        emit MoveCommitted(_gameId, msg.sender, game.currentTurn);

        // If both players have committed, set the reveal deadline
        if (game.commitA != bytes32(0) && game.commitB != bytes32(0)) {
            game.revealDeadline = block.timestamp + game.timeoutInterval;
        }
    }

    /**
     * @notice Reveal committed move
     * @param _gameId ID of the game
     * @param _move Player's move (1=Rock, 2=Paper, 3=Scissors)
     * @param _salt Random salt used in the commit phase
     */
    function revealMove(uint256 _gameId, uint8 _move, bytes32 _salt) external {
        Game storage game = games[_gameId];

        require(msg.sender == game.playerA || msg.sender == game.playerB, "Not a player in this game");
        require(game.state == GameState.Committed, "Game not in reveal phase");
        require(block.timestamp <= game.revealDeadline, "Reveal phase timed out");
        require(_move >= 1 && _move <= 3, "Invalid move");

        Move move = Move(_move);
        bytes32 commit = keccak256(abi.encodePacked(move, _salt));

        if (msg.sender == game.playerA) {
            require(commit == game.commitA, "Hash doesn't match commitment");
            require(game.moveA == Move.None, "Move already revealed");
            game.moveA = move;
        } else {
            require(commit == game.commitB, "Hash doesn't match commitment");
            require(game.moveB == Move.None, "Move already revealed");
            game.moveB = move;
        }

        emit MoveRevealed(_gameId, msg.sender, move, game.currentTurn);

        // If both players have revealed, determine the winner for this turn
        if (game.moveA != Move.None && game.moveB != Move.None) {
            _determineWinner(_gameId);
        }
    }

    /**
     * @notice Claim win if opponent didn't reveal in time
     * @param _gameId ID of the game
     */
    function timeoutReveal(uint256 _gameId) external {
        Game storage game = games[_gameId];

        require(msg.sender == game.playerA || msg.sender == game.playerB, "Not a player in this game");
        require(game.state == GameState.Committed, "Game not in reveal phase");
        require(block.timestamp > game.revealDeadline, "Reveal phase not timed out yet");

        // If player calling timeout has revealed but opponent hasn't, they win
        bool playerARevealed = game.moveA != Move.None;
        bool playerBRevealed = game.moveB != Move.None;

        if (msg.sender == game.playerA && playerARevealed && !playerBRevealed) {
            // Player A wins by timeout
            _finishGame(_gameId, game.playerA);
        } else if (msg.sender == game.playerB && playerBRevealed && !playerARevealed) {
            // Player B wins by timeout
            _finishGame(_gameId, game.playerB);
        } else if (!playerARevealed && !playerBRevealed) {
            // Neither player revealed, cancel the game and refund
            _cancelGame(_gameId);
        } else {
            revert("Invalid timeout claim");
        }
    }

    /**
     * @notice Check if a game is eligible for a reveal timeout
     * @param _gameId ID of the game to check
     * @return canTimeout Whether the game can be timed out
     * @return winnerIfTimeout The address of the winner if timed out, or address(0) if tied
     */
    function canTimeoutReveal(uint256 _gameId) external view returns (bool canTimeout, address winnerIfTimeout) {
        Game storage game = games[_gameId];

        if (game.state != GameState.Committed || block.timestamp <= game.revealDeadline) {
            return (false, address(0));
        }

        bool playerARevealed = game.moveA != Move.None;
        bool playerBRevealed = game.moveB != Move.None;

        if (playerARevealed && !playerBRevealed) {
            return (true, game.playerA);
        } else if (!playerARevealed && playerBRevealed) {
            return (true, game.playerB);
        } else if (!playerARevealed && !playerBRevealed) {
            return (true, address(0)); // Both forfeit
        }

        return (false, address(0));
    }

    /**
     * @notice Cancel game and refund if still in created state
     * @param _gameId ID of the game
     */
    function cancelGame(uint256 _gameId) external {
        Game storage game = games[_gameId];

        require(game.state == GameState.Created, "Game must be in created state");
        require(msg.sender == game.playerA, "Only creator can cancel");

        _cancelGame(_gameId);
    }

    /**
     * @notice Cancel game if the join timeout has passed and no one has joined
     * @param _gameId ID of the game
     */
    function timeoutJoin(uint256 _gameId) external {
        Game storage game = games[_gameId];

        require(game.state == GameState.Created, "Game must be in created state");
        require(block.timestamp > game.joinDeadline, "Join deadline not reached yet");
        require(game.playerB == address(0), "Someone has already joined the game");

        _cancelGame(_gameId);
    }

    /**
     * @notice Set the join timeout period (admin function)
     * @param _newTimeout New timeout value in seconds
     */
    function setJoinTimeout(uint256 _newTimeout) external {
        require(msg.sender == owner(), "Only owner can set timeout");
        require(_newTimeout >= 1 hours, "Timeout must be at least 1 hour");

        uint256 oldTimeout = joinTimeout;
        joinTimeout = _newTimeout;

        emit JoinTimeoutUpdated(oldTimeout, _newTimeout);
    }

    /**
     * @notice Check if a game is eligible for a join timeout
     * @param _gameId ID of the game to check
     * @return True if the game can be timed out, false otherwise
     */
    function canTimeoutJoin(uint256 _gameId) external view returns (bool) {
        Game storage game = games[_gameId];

        return (game.state == GameState.Created && block.timestamp > game.joinDeadline && game.playerB == address(0));
    }

    /**
     * @notice Get the contract owner (the deployer)
     * @return The owner address
     */
    function owner() public view returns (address) {
        return adminAddress;
    }

    /**
     * @notice Get the owner of the token contract
     * @return The token owner address
     */
    function tokenOwner() public view returns (address) {
        return winningToken.owner();
    }

    /**
     * @notice Set a new admin address (only callable by current admin)
     * @param _newAdmin The new admin address
     */
    function setAdmin(address _newAdmin) external {
        require(msg.sender == adminAddress, "Only admin can set new admin");
        require(_newAdmin != address(0), "Admin cannot be zero address");

        adminAddress = _newAdmin;
    }

    /**
     * @notice Allows the admin to withdraw accumulated protocol fees
     * @param _amount The amount to withdraw (0 for all)
     */
    function withdrawFees(uint256 _amount) external {
        require(msg.sender == adminAddress, "Only admin can withdraw fees");

        uint256 amountToWithdraw = _amount == 0 ? accumulatedFees : _amount;
        require(amountToWithdraw <= accumulatedFees, "Insufficient fee balance");

        accumulatedFees -= amountToWithdraw;

        (bool success,) = adminAddress.call{value: amountToWithdraw}("");
        require(success, "Fee withdrawal failed");

        emit FeeWithdrawn(adminAddress, amountToWithdraw);
    }

    /**
     * @dev Internal function to determine winner for the current turn
     * @param _gameId ID of the game
     */
    function _determineWinner(uint256 _gameId) internal {
        Game storage game = games[_gameId];

        address turnWinner = address(0);

        // Rock = 1, Paper = 2, Scissors = 3
        if (game.moveA == game.moveB) {
            // Tie, no points
            turnWinner = address(0);
        } else if (
            (game.moveA == Move.Rock && game.moveB == Move.Scissors)
                || (game.moveA == Move.Paper && game.moveB == Move.Rock)
                || (game.moveA == Move.Scissors && game.moveB == Move.Paper)
        ) {
            // Player A wins
            game.scoreA++;
            turnWinner = game.playerA;
        } else {
            // Player B wins
            game.scoreB++;
            turnWinner = game.playerB;
        }

        emit TurnCompleted(_gameId, turnWinner, game.currentTurn);

        // Reset for next turn or end game
        if (game.currentTurn < game.totalTurns) {
            // Reset for next turn
            game.currentTurn++;
            game.commitA = bytes32(0);
            game.commitB = bytes32(0);
            game.moveA = Move.None;
            game.moveB = Move.None;
            game.state = GameState.Committed;
        } else {
            // End game
            address winner;
            if (game.scoreA > game.scoreB) {
                winner = game.playerA;
            } else if (game.scoreB > game.scoreA) {
                winner = game.playerB;
            } else {
                // This should never happen with odd turns, but just in case
                // of timeouts or other unusual scenarios, handle as a tie
                _handleTie(_gameId);
                return;
            }

            _finishGame(_gameId, winner);
        }
    }

    /**
     * @dev Internal function to finish the game and distribute prizes
     * @param _gameId ID of the game
     * @param _winner Address of the winner
     */
    function _finishGame(uint256 _gameId, address _winner) internal {
        Game storage game = games[_gameId];

        game.state = GameState.Finished;

        uint256 prize = 0;

        // Handle ETH prizes
        if (game.bet > 0) {
            // Calculate total pot and fee
            uint256 totalPot = game.bet * 2; // *2 for both?
            uint256 fee = (totalPot * PROTOCOL_FEE_PERCENT) / 100;
            prize = totalPot - fee;

            // Accumulate fees for admin to withdraw later
            accumulatedFees += fee;
            emit FeeCollected(_gameId, fee);

            // Send prize to winner
            (bool success,) = _winner.call{value: prize}("");
            require(success, "Transfer failed");
        }

        // Handle token prizes - winner gets both tokens
        if (game.bet == 0) {
            // Mint a winning token
            winningToken.mint(_winner, 2);
        } else {
            // Mint a winning token for ETH games too
            winningToken.mint(_winner, 1);
        }

        emit GameFinished(_gameId, _winner, prize);
    }

    /**
     * @dev Handle a tie
     * @param _gameId ID of the game
     */
    function _handleTie(uint256 _gameId) internal {
        Game storage game = games[_gameId];

        game.state = GameState.Finished;

        // Return ETH bets to both players, minus protocol fee
        if (game.bet > 0) {
            // Calculate protocol fee (10% of total pot)
            uint256 totalPot = game.bet * 2;
            uint256 fee = (totalPot * PROTOCOL_FEE_PERCENT) / 100;
            uint256 refundPerPlayer = (totalPot - fee) / 2;

            // Accumulate fees for admin
            accumulatedFees += fee;
            emit FeeCollected(_gameId, fee);

            // Refund both players
            (bool successA,) = game.playerA.call{value: refundPerPlayer}("");
            (bool successB,) = game.playerB.call{value: refundPerPlayer}("");
            require(successA && successB, "Transfer failed");
        }

        // Return tokens for token games
        if (game.bet == 0) {
            winningToken.mint(game.playerA, 1);
            winningToken.mint(game.playerB, 1);
        }

        // Since in a tie scenario, the total prize is split equally
        emit GameFinished(_gameId, address(0), 0);
    }

    /**
     * @dev Cancel game and refund
     * @param _gameId ID of the game
     */
    function _cancelGame(uint256 _gameId) internal {
        Game storage game = games[_gameId];

        game.state = GameState.Cancelled;

        // Refund ETH to players
        if (game.bet > 0) {
            (bool successA,) = game.playerA.call{value: game.bet}("");
            require(successA, "Transfer to player A failed");

            if (game.playerB != address(0)) {
                (bool successB,) = game.playerB.call{value: game.bet}("");
                require(successB, "Transfer to player B failed");
            }
        }

        // Return tokens for token games
        if (game.bet == 0) {
            if (game.playerA != address(0)) {
                winningToken.mint(game.playerA, 1);
            }
            if (game.playerB != address(0)) {
                winningToken.mint(game.playerB, 1);
            }
        }

        emit GameCancelled(_gameId);
    }

    /**
     * @dev Fallback function to accept ETH
     */
    receive() external payable {
        // Allow contract to receive ETH
    }
}
