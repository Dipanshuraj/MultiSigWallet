// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;



contract multiSignWallet{
    

    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);

     event AdminTransfer(address indexed newAdmin);
     event OwnerAddition(address indexed owner);
     event OwnerRemoval(address indexed owner);

    address[]public owners;
    uint public numConfirmationsRequired;
    mapping (address=> bool) isOwner;
    address public admin;
    

    // track transactions ID to which owner addresses have confirmed
    mapping(uint256 => mapping(address => bool)) public isConfirmed;


    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations; }

    Transaction[] public transactions;
    

    //helper function
    function ceil(uint a, uint m)internal pure returns (uint r) {
        uint t =a/m;
        if(a-t*m>=m/2){t++;}
        return t;   }
    

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin restricted function");
        _;
    }

      modifier notNull(address _address) {
        require(_address != address(0), "Specified destination doesn't exist");
        _;
    }

        modifier notOwnerExistsMod(address owner) {
        require(isOwner[owner] == false, "This owner already exists");
        _;
    }

        modifier ownerExistsMod(address owner) {
        require(isOwner[owner] == true, "This owner doesn't exist");
        _;
    }
        modifier onlyOwner(){
        require(isOwner[msg.sender],"not Owner");
        _;
    }
    modifier txExists(uint _txIndex){
        require(_txIndex<transactions.length,"txn does not exist");
        _;
    }
    modifier notExecuted(uint _txIndex){
        require(!transactions[_txIndex].executed,"txn already executed");
        _;
    }
    modifier notConfirmed(uint _txIndex){
        require(!isConfirmed[_txIndex][msg.sender],"txn already confirmed");
        _;
    }




// ["0xCEb9024943496E99F6e69907c3072626f9348f87","0xf5B19ECEa48fe4Ff9D7eA0C423F0fB22bC0487C3","0x6EBDff1C57c264613FBB06eD2E02fA9d8f4F090E"]
// 1000000000000000000
        

    constructor(address [] memory _owners){
            admin = msg.sender;
            //60% authorization by the signatory
            uint _numConfirmationsRequired= ceil(_owners.length*60,100);

            require(_owners.length>=3,"need atleast 3 owners");
            require(_numConfirmationsRequired>0&&_numConfirmationsRequired <= _owners.length,"Not enough required confirmation");
            
            for(uint i=0; i<_owners.length;i++){
                address owner= _owners[i];
                    require(owner != address(0),"invalid owner");
                    require(!isOwner[owner],"owner not unique");
                        isOwner[owner]=true;
                        owners.push(owner);     
            }
           numConfirmationsRequired=_numConfirmationsRequired; }
    


    function submitTransaction(address _to,uint _value, bytes memory _data) public  onlyOwner {

            uint txIndex = transactions.length;
 
            transactions.push(Transaction({
                    to: _to,
                    value: _value,
                    data: _data,
                    executed: false,            
                    numConfirmations:0
                }));
            emit SubmitTransaction(msg.sender, txIndex,_to,_value,_data);

             }
    

    function confirmTransaction (uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
             Transaction storage transaction= transactions[_txIndex] ;
        
             isConfirmed[_txIndex][msg.sender] =true;
             transaction.numConfirmations+=1;

             emit ConfirmTransaction(msg.sender, _txIndex);
    }


    function executeTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
                Transaction storage transaction= transactions[_txIndex];
                require(transaction.numConfirmations>=numConfirmationsRequired,"can not execute txn");
                transaction.executed= true;


                (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
                require(success, "Transfer failed.");
                emit ExecuteTransaction(msg.sender,_txIndex);
                 }



    function testTransfer() external payable {}
    function getBalance() external view returns (uint256) {return address(this).balance;}


    function revokeConfirmation(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex){
        
        Transaction storage transaction = transactions[_txIndex];
        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");
        isConfirmed[_txIndex][msg.sender] = false;
        transaction.numConfirmations -= 1;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }


    function addOwner(address owner) public onlyAdmin notNull(owner) notOwnerExistsMod(owner){
                // add owner
                isOwner[owner] = true;
                owners.push(owner);

                // emit event
                emit OwnerAddition(owner);  }



    function renounceAdmin(address newAdmin) public onlyAdmin {
             admin = newAdmin;
             emit AdminTransfer(newAdmin);
               }


    function removeOwner(address owner) public onlyAdmin notNull(owner) ownerExistsMod(owner)
            {
                // remove owner
                isOwner[owner] = false;

                // iterate over owners and remove the current owner
                for (uint256 i = 0; i < owners.length - 1; i++)
                    if (owners[i] == owner) {
                        owners[i] = owners[owners.length - 1];
                        break;
                    }
                owners.pop();
                                }


    function transferOwner(address _from, address _to) public onlyAdmin notNull(_from) notNull(_to) ownerExistsMod(_from) notOwnerExistsMod(_to)
            {
                // iterate over owners
                for (uint256 i = 0; i < owners.length; i++)
                    // if the curernt owner
                    if (owners[i] == _from) {
                        // replace with new owner address
                        owners[i] = _to;
                        break;
                    }

                // reset owner addresses
                isOwner[_from] = false;
                isOwner[_to] = true;

                // emit events
                emit OwnerRemoval(_from);
                emit OwnerAddition(_to);
            }


}