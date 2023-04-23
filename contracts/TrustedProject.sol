// SPDX-License-Identifier: MIT
pragma solidity >0.8.19;

contract User {
    enum MemberRole {CREATOR, CUSTOMER};
    address public immutable memberAddress;
    MemberRole public immutable role;
    bool private _isSatisfied;

    event SatisfactionChanged(bool state);

    constructor(address _memberAddress, MemberRole _role) {
        memberAddress = _memberAddress;
        _isSatisfied = false;
        role = _role;
    }

    function setIsSatisfied(bool newSatisfied) external {
        require(newSatisfied != _isSatisfied, "DV");       // duplicate value
        _isSatisfied = newSatisfied;
        emit SatisfactionChanged(newSatisfied);
    }

    function requireSatisfied() external view {
        require(_isSatisfied, "AS");     // already satisfied
    }

    function requireNotSatisfied() external view {
        require(!_isSatisfied, "NS");     // not satisfied
    }
}

contract TrustedProject {
    modifier onlyCreator() {
        require(msg.sender == creator.memberAddress, "IU");     // invalid user
        _;
    }

    modifier onlyCustomer() {
        require(msg.sender == customer.memberAddress, "IU");    // invalid user
        _;
    }

    uint private _payment = 0;
    string[] private projectLinks;

    event ProjectCompleted();
    event PaymentAdded(uint amount, indexed address account);
    event PaymentReceived(uint amount);

    User public immutable creator;
    User public immutable customer;

    constructor(address _customerAddress, address _creatorAddress) {
        creator = new User(_creatorAddress, User.MemberRole.CREATOR);
        customer = new User(_customerAddress, User.MemberRole.CUSTOMER);
    }

    receive() external payable { addPayment(); }

    function addPayment() external payable {
        require(msg.value > 0, "FN");       // funds are negative
        _payment += msg.value;
        emit PaymentAdded(msg.value, msg.sender);
    }

    function getPayment() external view returns(uint){
        return _payment;
    }

    function uploadProject(string memory _projectLink, bool isSatisfied) external onlyCreator {
        projectLinks.push(_projectLink);

        if(isSatisfied){
            creator.setIsSatisfied(true);
        }
    }

    function getProjectLinks() external view onlyCustomer returns (string[] memory) {
        creator.requireSatisfied();
        return projectLinks;
    }

    function completeProject() external onlyCustomer {
        creator.setIsSatisfied(true);
        emit ProjectCompleted();
    }

    function receivePayment(uint amount) external onlyCreator {
        customer.requireSatisfied();
        creator.requireSatisfied();
        require(amount <= _payment, "NEF");     // not enough funds

        _payment -= amount;
        (bool isSent, ) = creator.getAddress().call{ value: amount }("");
        require(isSent, "TE");      // transfer error

        emit PaymentReceived(amount);
    }
}
