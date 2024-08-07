// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Lottery {
    struct LotteryTicket {
        mapping(address => uint16) userWinningNumber;
        mapping(address => bool) isBuy;
        mapping(address => bool) isClaim;
        uint16 winningNumber;
        uint256 timestamp;
        bool isDraw;
    }

    LotteryTicket public ticket;
    uint256 public prizePool;
    uint256 correctCount;
    address[] ticketHolders;

    uint256 constant DRAW_INTERVAL = 24 hours;

    constructor() {
        ticket.winningNumber = 0;
        ticket.timestamp = block.timestamp;
    }
    event Log(uint256 prizePool, uint256 correctCount);

    function buy(uint16 _winningNumber) external payable {
        require(msg.value == 0.1 ether, "Lottery: incorrect value");
        require(!ticket.isBuy[msg.sender], "Lottery: already bought");
        require(
            block.timestamp - ticket.timestamp < DRAW_INTERVAL,
            "Lottery: draw phase started"
        );
        if (ticket.isDraw) {
            ticket.isDraw = false;
        }
        ticketHolders.push(msg.sender);
        ticket.userWinningNumber[msg.sender] = _winningNumber;
        ticket.isBuy[msg.sender] = true;
        ticket.isClaim[msg.sender] = false;
        prizePool += msg.value;
    }

    function draw() external {
        require(
            block.timestamp - ticket.timestamp >= DRAW_INTERVAL,
            "Lottery: draw phase not started"
        );
        require(!ticket.isDraw, "Lottery: already drawn");
        ticket.winningNumber = uint16(
            uint256(
                keccak256(abi.encodePacked(block.timestamp, block.prevrandao))
            ) % 1000000
        );
        ticket.timestamp = block.timestamp;
        ticket.isDraw = true;
        correctCount = getWinnersCount();
    }

    function winningNumber() external view returns (uint16) {
        return ticket.winningNumber;
    }

    function claim() external {
        require(ticket.isDraw, "Lottery: not drawn");
        require(!ticket.isClaim[msg.sender], "Lottery: already claimed");
        emit Log(prizePool, correctCount);
        if (ticket.userWinningNumber[msg.sender] == ticket.winningNumber) {
            uint256 prize = prizePool / correctCount;
            prizePool -= prize;
            correctCount--;
            (bool success, ) = msg.sender.call{value: prize, gas: 100000}(
                "" // outOfGas 발생 gas 늘려줌
            );
            require(success, "Failed to send Ether");
        }
        removeTicketHolder(msg.sender);
        ticket.isBuy[msg.sender] = false;
        ticket.isClaim[msg.sender] = true;
    }

    function getWinnersCount() internal view returns (uint256) {
        uint256 winnersCount = 0;
        for (uint256 i = 0; i < ticketHolders.length; i++) {
            if (
                ticket.userWinningNumber[ticketHolders[i]] ==
                ticket.winningNumber
            ) {
                winnersCount++;
            }
        }
        return winnersCount;
    }

    function removeTicketHolder(address _holder) internal {
        for (uint256 i = 0; i < ticketHolders.length; i++) {
            if (ticketHolders[i] == _holder) {
                ticketHolders[i] = ticketHolders[ticketHolders.length - 1];
                ticketHolders.pop();
                break;
            }
        }
    }

    receive() external payable {}
}
