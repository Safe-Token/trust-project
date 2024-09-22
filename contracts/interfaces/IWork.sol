// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


enum WorkState{
    INITIALIZED,
    PAYMENT_ADDED,
    WORK_CHECKING,
    DISPUTE_STARTED,
    PAYMENT_RELEASED,
    REFUND_RELEASED
}


interface IWork {
    event PaymentAdded(uint256 amount, uint indexed blockNumber);
    event WorkCompleted(uint indexed blockNumber);
    event PaymentReleased(uint amount, uint indexed blockNumber);
    event DisputeResolved(bool workerWins, uint indexed blockNumber);

    function getState() view external returns(WorkState);

    // Normal flow
    function addPayment(uint256 _paymentAmount) external;
    function finishWork(bytes memory _workData) external;
    function releasePayment() external;

    // Dispute flow
    function startDispute(string memory _disputeQuestion, string memory _disputeContext, uint rewardAmount) external;
    function resolveDispute() external;
}
