// SPDX-License-Identifier: MIT

 

pragma solidity ^0.8.0;

 

import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/token/ERC20/IERC20Upgradeable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/access/AccessControlUpgradeable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import "./Whitelist.sol";

 

contract CarbonContract is ERC1155Upgradeable, AccessControlUpgradeable {
    
    mapping(uint => bool) public pauseStatus;
    mapping(address => string) public fileURI;
    address public retiredAddress;
    
    event CarbonMinted(address _address, uint _id, uint _amount);
    event CarbonSpawned(address _address, uint _id, uint _amount, uint factor);
    event Paused(uint projectID, bool status);
    event Unpaused(uint projectID, bool status);
    event CarbonBurned(address _address, uint _id, uint _amount);
    event CarbonBurnedBatch(address _address, uint [] _ids, uint [] _amounts);
    event CarbonRetired(address _address, uint _id, uint _amount);
    event CarbonRetiredBatch(address _address, uint [] _ids, uint [] _amounts);
    event ForcedTransferred(address _address,address _to, uint _id, uint amount,bytes data );
    event TransferBatch(address _from, address _to, uint256[] ids, uint256[] amounts, bytes data);
    event TransferSingle(address _from, address _to, uint _id, uint _amount, bytes data);
    event RoleGranted(address GrantedTo, bytes32 Role);
    event RoleRevoked(address RevokedFor, bytes32 Role);
    event ContractURISet(address ContractAddress, string URI);
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FORCEDTRANSFER_ROLE = keccak256("FORCEDTRANSFER_ROLE");
    bytes32 public constant EDITOR_ROLE = keccak256("EDITOR_ROLE");
    
    Whitelist whitelistContract;
    
    function initialize(address _whitelistAddr, address adminAddr, address minterAddr, address burnerAddr, address pauserAddr, address forceAddr, address setWhiteAddr) initializer external {
        __ERC1155_init("Carbon");
        whitelistContract = Whitelist(_whitelistAddr);
        retiredAddress = 0x000000000000000000000000000000000000dEaD;
        
        _setupRole(DEFAULT_ADMIN_ROLE, adminAddr);
        _setupRole(MINTER_ROLE, minterAddr);
        _setupRole(BURNER_ROLE, burnerAddr);
        _setupRole(PAUSER_ROLE, pauserAddr);
        _setupRole(FORCEDTRANSFER_ROLE, forceAddr);
        _setupRole(EDITOR_ROLE, setWhiteAddr);
    }
    
    function isAdmin() public view returns(bool) {
        if(hasRole(DEFAULT_ADMIN_ROLE,msg.sender))
            return true;
        return false;
    }
    
    function setWhiteListContract(address _address) public {
        require(hasRole(EDITOR_ROLE, msg.sender) || isAdmin(), "You don't have access");
        whitelistContract = Whitelist(_address);
    }
    
    function setContractURI(address _address, string memory URI) public {
        require(hasRole(EDITOR_ROLE, msg.sender) || isAdmin(), "You don't have access");
        require(whitelistContract.isSpawnlisted(_address), "Your contract is not spawnlisted!");
        
        fileURI[_address] = URI;
    
        emit ContractURISet(_address, URI);
    }
    
    function pause(uint projectID) external {
        require(isAdmin() || hasRole(PAUSER_ROLE, msg.sender), "Only admin is allowed to Pause");
        require(pauseStatus[projectID] == false, "Already Paused");
        
        pauseStatus[projectID] = true;
        emit Paused(projectID , pauseStatus[projectID]);
    }

 

    function unpause(uint projectID) external {
        require(isAdmin() || hasRole(PAUSER_ROLE, msg.sender), "Only admin is allowed to Unpause");
        require(pauseStatus[projectID] == true, "Already Unpaused");
        
        pauseStatus[projectID] = false;
        emit Unpaused(projectID ,pauseStatus[projectID]);
    }

 

    function mint(address _address, uint _id, uint _amount) public {
        require(isAdmin() || hasRole(MINTER_ROLE, msg.sender), "Don't have access privileges");
        require(whitelistContract.isWhitelisted(_address), "Address needs to be whitelisted first");
        require(_amount > 0, "Amount cannot be zero or less");
        
        _mint(_address, _id, _amount, '');
        
        emit CarbonMinted(_address, _id, _amount);
    }

 

    function spawnCarbonbyProject(address [] memory _address, uint [] memory _amounts, uint _id, uint _factor) public {
        require(whitelistContract.isSpawnlisted(msg.sender), "Contract isn't approved to spawn yet");
        
        for(uint i = 0; i < _address.length; i++){
            if(_amounts[i] > 0){
                _mint(_address[i], _id, _amounts[i] * _factor, '');
                emit CarbonSpawned(_address[i], _id, _amounts[i], _factor);
            }
        }
    }
    
    function forceTransfer(address _from, address _to,uint _id, uint _amount) public {
        require(isAdmin() || hasRole(FORCEDTRANSFER_ROLE, msg.sender ), "Don't have access to force transfer");
        require(whitelistContract.isWhitelisted(_from) && whitelistContract.isWhitelisted(_to), "Address needs to be whitelisted first");
        require(_amount > 0, "Amount cannot be zero or less");
        
         _safeTransferFrom(_from,_to, _id, _amount, '');
        emit ForcedTransferred(_from, _to, _id, _amount ,'');
    }
    
    function safeBatchTransferFrom(address _from, address _to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual override(ERC1155Upgradeable) {
        require(whitelistContract.isWhitelisted(_from) && whitelistContract.isWhitelisted(_to), "Address needs to be whitelisted first");
        
        for(uint i = 0; i < ids.length; i++){
            require(pauseStatus[ids[i]] == false, "Project Transfers are paused!");
        }
        
        super.safeBatchTransferFrom(_from, _to, ids,amounts,data);
        emit TransferBatch(_from, _to, ids, amounts, data);
     }
     
     function safeTransferFrom(address _from, address _to, uint _id, uint _amount, bytes memory data) public virtual override(ERC1155Upgradeable) {
        require(whitelistContract.isWhitelisted(_from) && whitelistContract.isWhitelisted(_to), "Address needs to be whitelisted first");
        require(pauseStatus[_id] == false, "Project Transfers are paused!");
        require(_amount > 0, "Amount should be more than zero");
        
        super.safeTransferFrom(_from, _to, _id,_amount, data);
        emit TransferSingle(_from, _to, _id, _amount,data);
    }
    
    function burnCarbon(address _from, uint _id, uint _amount) public {
        require(isAdmin() || hasRole(BURNER_ROLE, msg.sender), "You don't have access");
        require(balanceOf(_from ,_id) > 0, "Balance cannot be zero");
        _burn(_from, _id, _amount);
    
        emit CarbonBurned(_from, _id, _amount);    
    }
    
    function burnCarbonBulk(address _from, uint [] memory _ids, uint [] memory _amounts) public {
        require(isAdmin() || hasRole(BURNER_ROLE, msg.sender), "You don't have access");
        require(_ids.length == _amounts.length, "Values entered are incorrect");
        
        _burnBatch(_from, _ids, _amounts);
    
        emit CarbonBurnedBatch(_from, _ids, _amounts);
    }
    
    function retireCarbon(address _from, uint _id, uint _amount) public {
        require(isAdmin() || hasRole(BURNER_ROLE, msg.sender), "You don't have access");
        require(balanceOf(_from ,_id) > 0, "Balance cannot be zero");
        _safeTransferFrom(_from , retiredAddress, _id, _amount, '');
    
        emit CarbonRetired(_from, _id, _amount);    
    }
    
    function retireCarbonBulk(address _from, uint [] memory _ids, uint [] memory _amounts) public {
        require(isAdmin() || hasRole(BURNER_ROLE, msg.sender), "You don't have access");
        require(_ids.length == _amounts.length, "Values entered are incorrect");
        
        _safeBatchTransferFrom(_from, retiredAddress, _ids, _amounts, '');
        emit CarbonRetiredBatch(_from, _ids, _amounts);
    }
    
    function grantRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable) onlyRole(getRoleAdmin(role)) {
        require(whitelistContract.isWhitelisted(account), "Must whitelist first");
            
        super.grantRole(role, account);
        emit RoleGranted(account, role);
    }

 

    function revokeRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable) onlyRole(getRoleAdmin(role)) {
        require(account != msg.sender, "You can't revoke your role");
            
        super.revokeRole(role, account);
        emit RoleRevoked(account, role);
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
     }
}
