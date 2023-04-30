// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;


contract TrustedProject {
    modifier onlyCreator {
        require(msg.sender == creator, "IU");     // invalid user
        _;
    }

    modifier onlyCustomer {
        require(msg.sender == customer, "IU");    // invalid user
        _;
    }

    modifier onlyDirectMembers {
        require(msg.sender == customer || msg.sender == creator, "IU");    // invalid user
        _;
    }

    modifier onlyMembers {
        require(msg.sender == customer || msg.sender == creator || (projectState == ProjectState.DISPUTE && isArbitrage(msg.sender)), "IU");
        _;
    }

    modifier onlyArbitrage {
        require(isArbitrage(msg.sender), "IU");  // invalid user
        _;
    }

    uint private _payment = 0;
    string[] private projectData;

    enum ProjectState {CREATED, PAID, UPLOADED, FINISHED, DISPUTE }
    ProjectState private projectState = ProjectState.CREATED;
    event ProjectStateChanged(ProjectState newState);
    event PaymentAdded(uint amount);

    address public immutable creator;
    address public immutable customer;

    // INVALID_USER is the default value in the map. We use it to check whether someone is an arbitrage or not.
    enum ArbitrageDecision{ INVALID_USER, UNDECIDED, CUSTOMER, CREATOR }
    mapping(address => ArbitrageDecision) private arbitrageDecisions;
    address[] private arbitrage;
    uint private totalArbitrageDecisions = 0;
    uint private disputeDecisionSum = 0;

    constructor(address _customerAddress, address _creatorAddress, address[] memory _arbitrage) {
        customer = _customerAddress;
        creator = _creatorAddress;

        arbitrage = _arbitrage;

        for (uint i = 0; i < _arbitrage.length; i++) {
            arbitrageDecisions[_arbitrage[i]] = ArbitrageDecision.UNDECIDED;
        }

        require(_customerAddress != _creatorAddress, "IU");     // invalid user
        require(!isArbitrage(customer) && !isArbitrage(creator), "IA");     // invalid arbitrage
    }

    function getProjectState() external onlyMembers view returns(ProjectState){
        return projectState;
    }

    function addPayment() public onlyCustomer payable {
        require(msg.value > 0, "FN");       // Funds are negative
        _payment += msg.value;

        if(projectState == ProjectState.CREATED){
            // We check that to maybe add additional payment later and not change the state
            projectState = ProjectState.PAID;
            emit ProjectStateChanged(projectState);
        }

        emit PaymentAdded(msg.value);
    }    

    receive() external payable {
        addPayment();
    }

    function getPayment() external onlyMembers view returns(uint){
        return _payment;
    }

    function uploadProject(string memory _projectData) external onlyCreator {
        require(projectState == ProjectState.PAID, "IS");    // Invalid state
        projectData.push(_projectData);

        if(projectState != ProjectState.UPLOADED){
            projectState = ProjectState.UPLOADED;
            emit ProjectStateChanged(projectState);
        }
    }

    function getProjectData() external view onlyMembers returns (string[] memory) {
        if(isArbitrage(msg.sender)){
            // arbitrage can only view data if it is a dispute
            require(projectState == ProjectState.DISPUTE, "IS");
        }

        require(projectState == ProjectState.UPLOADED, "IS");
        return projectData;
    }

    function completeProject() external onlyCustomer {
        require(projectState == ProjectState.UPLOADED, "IS");   // invalid state

        (bool isSent, ) = creator.call{ value: _payment }("");
        require(isSent, "TE");      // transfer error

        _payment = 0;

        projectState = ProjectState.FINISHED;
        emit ProjectStateChanged(projectState);
    }

    function openDispute() external onlyDirectMembers{
        // we have just created/finished the project - there is no dispute. Otherwise, it is already open
        require(projectState != ProjectState.CREATED && projectState != ProjectState.FINISHED && projectState != ProjectState.DISPUTE, "IS");

        projectState = ProjectState.DISPUTE;
        emit ProjectStateChanged(projectState);
    }

    function getArbitrage() external view onlyMembers returns(address[] memory){
        return arbitrage;
    }

    function isArbitrage(address checkedAddress) public view onlyMembers returns(bool){
        return arbitrageDecisions[checkedAddress] != ArbitrageDecision.INVALID_USER;
    }
    
    function arbitrageDecide(bool isCustomerCorrect) external onlyArbitrage{
        require(projectState == ProjectState.DISPUTE, "IS");
        ArbitrageDecision oldDecision = arbitrageDecisions[msg.sender];

        if(oldDecision == ArbitrageDecision.UNDECIDED){
            // each wallet decision is only counted once
            totalArbitrageDecisions++;
        }

        arbitrageDecisions[msg.sender] = isCustomerCorrect ? ArbitrageDecision.CUSTOMER : ArbitrageDecision.CREATOR;

        if(oldDecision == arbitrageDecisions[msg.sender]){
            return;
        }else if(isCustomerCorrect){
            disputeDecisionSum++;
        }else{
            disputeDecisionSum--;
        }
    }

    function getDisputeDecision() public view onlyMembers returns(ArbitrageDecision){
        require(projectState == ProjectState.DISPUTE, "IS");

        if(totalArbitrageDecisions < arbitrage.length / 2){
            return ArbitrageDecision.UNDECIDED;
        } else if(disputeDecisionSum > 0){
            return ArbitrageDecision.CUSTOMER;
        }else if(disputeDecisionSum < 0){
            return ArbitrageDecision.CREATOR;
        }

        return ArbitrageDecision.UNDECIDED;
    }

    function finishDispute() external onlyMembers{
        ArbitrageDecision decision = getDisputeDecision();
        require(projectState == ProjectState.DISPUTE || decision == ArbitrageDecision.UNDECIDED, "IS");

        address winnerAddress;

        if(decision == ArbitrageDecision.CUSTOMER){
            winnerAddress = customer;
        }else if(decision == ArbitrageDecision.CREATOR){
            winnerAddress = creator;
        }

        (bool isSent, ) = winnerAddress.call{ value: _payment }("");
        require(isSent, "TE");      // transfer error

        projectState = ProjectState.FINISHED;
        emit ProjectStateChanged(projectState);
    }

}
