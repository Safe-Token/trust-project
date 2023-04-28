// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

contract User {
    enum MemberRole {CREATOR, CUSTOMER}
    address public immutable memberAddress;
    MemberRole public immutable role;
    bool private _isSatisfied;

    event SatisfactionChanged(bool state);

    constructor(address _memberAddress, MemberRole _role) {
        memberAddress = _memberAddress;
        _isSatisfied = false;
        role = _role;
    }

    function isSatisfied() external view returns(bool){
        return _isSatisfied;
    }

    function setIsSatisfied(bool newSatisfied) external {
        _isSatisfied = newSatisfied;
        emit SatisfactionChanged(newSatisfied);
    }

    function requireSatisfied() external view {
        require(_isSatisfied, "NS");     // already satisfied
    }

    function requireNotSatisfied() external view {
        require(!_isSatisfied, "AS");     // not satisfied
    }
}

contract TrustedProject {
    modifier onlyCreator() {
        require(msg.sender == creator.memberAddress(), "IU");     // invalid user
        _;
    }

    modifier onlyCustomer() {
        require(msg.sender == customer.memberAddress(), "IU");    // invalid user
        _;
    }

    uint private _payment = 0;
    string[] private projectLinks;

    event ProjectCompleted();
    event PaymentAdded(uint amount, address account);

    User public immutable creator;
    User public immutable customer;

    constructor(address _customerAddress, address _creatorAddress) {
        creator = new User(_creatorAddress, User.MemberRole.CREATOR);
        customer = new User(_customerAddress, User.MemberRole.CUSTOMER);
    }

    function addPayment() public payable {
        require(msg.value > 0, "FN");       // funds are negative
        _payment += msg.value;
        emit PaymentAdded(msg.value, msg.sender);
    }

    receive() external payable {
        addPayment();
    }

    function getPayment() external view returns(uint){
        return _payment;
    }

    function uploadProject(string[] memory _newLinks, bool isSatisfied) external onlyCreator {
        for (uint i = 0; i < _newLinks.length; i++) {
            projectLinks.push(_newLinks[i]);
        }

        if(isSatisfied){
            creator.setIsSatisfied(true);
        }
    }

    function getProjectLinks() external view onlyCustomer returns (string[] memory) {
        creator.requireSatisfied();
        return projectLinks;
    }

    function completeProject() external onlyCustomer {
        creator.requireSatisfied();

        (bool isSent, ) = creator.memberAddress().call{ value: _payment }("");
        require(isSent, "TE");      // transfer error

        emit ProjectCompleted();
    }
}
