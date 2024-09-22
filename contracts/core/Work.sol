// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uma/core/contracts/optimistic-oracle-v3/interfaces/OptimisticOracleV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IWork.sol";


contract WorkContract is IWork {
    IERC20 public immutable paymentToken;
    OptimisticOracleV3Interface private immutable optimisticOracle;
    WorkState private state = WorkState.INITIALIZED;

    uint64 public immutable disputeWindow;
    address public creator;
    address public worker;
    uint256 public paymentAmount;

    bytes private workData;
    uint256 private workDoneBlock;

    bytes32 private disputeQuestion;
    bytes32 private disputeContext;

    constructor(
        address _paymentToken,
        address _optimisticOracle,
        address _worker,
        address _creator,
        uint64 _disputeWindow
    ) {
        paymentToken = IERC20(_paymentToken);
        optimisticOracle = OptimisticOracleV3Interface(_optimisticOracle);
        worker = _worker;
        creator = _creator;
        disputeWindow = _disputeWindow;
    }

    function addPayment(uint256 _paymentAmount) external {
        require(
            msg.sender == creator,
            "Initiator: only creator can add payment"
        );
        require(_paymentAmount > 0, "Payment: zero amount");

        paymentAmount = _paymentAmount;
        state = WorkState.PAYMENT_ADDED;

        require(
            paymentToken.transferFrom(creator, address(this), _paymentAmount),
            "Payment: failed to transfer"
        );
        emit PaymentAdded(_paymentAmount, block.number);
    }

    function finishWork(bytes memory _workData) external {
        require(
            msg.sender == worker,
            "Initiator: only the worker can signal work done."
        );
        require(paymentAmount > 0, "Payment: no payment yet");

        state = WorkState.WORK_CHECKING;
        workDoneBlock = block.number;
        workData = _workData;

        emit WorkCompleted(block.number);
    }

    function releasePayment() external {
        require(
            msg.sender == creator,
            "Initiator: only creator can release the payment"
        );
        require(
            state == WorkState.WORK_CHECKING ||
                state == WorkState.DISPUTE_STARTED,
            "Work: invalid state for payment release"
        );

        paymentAmount = 0;
        state = WorkState.PAYMENT_RELEASED;

        require(
            paymentToken.transfer(worker, paymentAmount),
            "Payment transfer failed."
        );
        emit PaymentReleased(paymentAmount, block.number);
    }

    function getState() external view returns (WorkState) {
        return state;
    }

    // ------------------------ Dispute flow ------------------------
    // All those functions are only relevant when there is a dispute in the project.
    // We use UMA oracles here to request a solution to this dispute.
    function startDispute(
        string memory _disputeQuestion,
        string memory _disputeContext,
        uint256 rewardAmount
    ) external {
        require(
            msg.sender == creator || msg.sender == worker,
            "Initiator: only the worker or creator can raise a dispute."
        );
        require(
            state == WorkState.WORK_CHECKING,
            "Work: must be completed first."
        );
        require(
            paymentAmount >= rewardAmount,
            "Payment: invalid reward amount"
        );

        state = WorkState.DISPUTE_STARTED;
        paymentAmount -= rewardAmount;
        disputeContext = keccak256(abi.encodePacked(_disputeContext));
        disputeQuestion = keccak256(abi.encodePacked(_disputeQuestion));

        optimisticOracle.assertTruth(
            abi.encode(_disputeQuestion),
            address(this),
            address(0),
            address(0),
            disputeWindow,
            paymentToken,
            rewardAmount,
            disputeQuestion,
            0
        );
    }

    function resolveDispute() external {
        require(
            state == WorkState.DISPUTE_STARTED,
            "Dispute: no active dispute."
        );
        bool workerWins = optimisticOracle.settleAndGetAssertionResult(disputeQuestion);

        if (workerWins) {
            state = WorkState.PAYMENT_RELEASED;
            require(
                paymentToken.transfer(worker, paymentAmount),
                "Payment transfer failed."
            );
        } else {
            state = WorkState.REFUND_RELEASED;
            require(
                paymentToken.transfer(creator, paymentAmount),
                "Payment transfer failed."
            );
        }

        emit DisputeResolved(workerWins, block.number);
    }
}
