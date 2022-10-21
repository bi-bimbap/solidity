// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

/*
The wallet owners can:
- submit a transaction
- approve and revoke approval of pending transcations
- anyone can execute a transcation after enough owners has approved it.

https://solidity-by-example.org/app/multi-sig-wallet/
https://www.youtube.com/watch?v=8ja72g_Dac4&list=PLO5VPQH6OWdVQwpQfw9rZ67O6Pjfo6q-p&index=53
*/

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);
    event Execute(uint indexed txId);

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    // check if msg.sender is owner before allowing them to submit transaction via submit()
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    // check if transaction exists
    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "transaction does not exist");
        _;
    }

    modifier notApproved(uint _txId) {
        require(!approved[_txId][msg.sender], "transaction already approved");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid required no. of owners");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i]; // save gas so that it does not access array multiple times
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner is not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    // allow wallet to receive ETH
    receive() external payable {
        // msg.value = amount sent to this contract when deployed
        emit Deposit(msg.sender, msg.value);
    }

    // only owners will be able to submit transactions, then get approval
    function submit(address _to, uint _value, bytes calldata _data) external onlyOwner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));

        emit Submit(transactions.length - 1); // index where transaction is stored
    }

    function approve(uint _txId) external onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId) {
        approved[_txId][msg.sender] = true;

        emit Approve(msg.sender, _txId);
    }

    // check if the min. no of approval has been obtained
    function _getApprovalCount(uint _txId) private view returns (uint count) {
        for (uint i; i < owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count += 1;
            }
        }
    }

    function execute(uint _txId) external txExists(_txId) notExecuted(_txId) {
        require(_getApprovalCount(_txId) >= required, "approvals < required");

        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;
        // low level call
        // transaction.data contains instructions for EVM, the function to call and the inputs to pass
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        require(success, "transaction failed");

        emit Execute(_txId);        
    }

    function revoke(uint _txId) external onlyOwner() txExists(_txId) notExecuted(_txId) {
        require(approved[_txId][msg.sender], "transaction not approved");
        approved[_txId][msg.sender] = false;

        emit Revoke(msg.sender, _txId);    
    }
}

contract TestContract {
    uint public i;

    function callMe(uint j) public {
        i += j;
    }

    function getData() public pure returns (bytes memory) {
        return abi.encodeWithSignature("callMe(uint256)", 123);
    }
}
