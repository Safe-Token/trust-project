// SPDX-License-Identifier: MIT
pragma solidity >0.8.19;

contract User {
    enum MemberRole {CREATOR, CUSTOMER};
    address public immutable memberAddress;
    MemberRole public immutable role;
    bool private _isSatisfied;

    constructor(address _memberAddress, MemberRole _role) {
        memberAddress = _memberAddress;
        _isSatisfied = false;
        role = _role;
    }

    function setIsSatisfied(bool newSatisfied) external {
        _isSatisfied = newSatisfied;
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
        require(msg.sender == creator.memberAddress);
        _;
    }

    modifier onlyCustomer() {
        require(msg.sender == customer.memberAddress);
        _;
    }

    uint private _payment = 0;
    string[] private projectLinks;

    User public immutable creator;
    User public immutable customer;

    constructor(address _customerAddress, address _creatorAddress) {
        creator = new User(_creatorAddress, User.MemberRole.CREATOR);
        customer = new User(_customerAddress, User.MemberRole.CUSTOMER);
    }

    function addPayment() external payable {
        require(msg.value > 0, "FN");       // funds are negative
        _payment += msg.value;
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

    function getProjectLinks() external onlyCustomer returns (string[] memory) {
        creator.requireSatisfied();
        customer.setIsSatisfied(true);
        return projectLinks;
    }

    function receivePayment(uint amount) external onlyCreator {
        customer.requireSatisfied();
        require(amount <= _payment, "NEF");      // not enough funds

        _payment -= amount;
        (bool isSent, ) = creator.getAddress().call{ value: amount }("");
        require(isSent, "TE");      // transfer error
    }
}
