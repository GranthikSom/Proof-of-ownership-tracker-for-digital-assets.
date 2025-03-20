// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DigitalAssetOwnership
 * @dev Smart contract for tracking ownership of digital assets
 */
contract DigitalAssetOwnership {
    // Struct to represent a digital asset
    struct DigitalAsset {
        string name;
        string description;
        string assetURI;      // URI to the asset or its metadata
        bytes32 contentHash;  // Hash of the digital content
        uint256 creationTime;
        address creator;
        address currentOwner;
        bool isTransferable;
        uint256 lastTransferTime;
        mapping(address => bool) authorizedUsers;
    }
    
    // Mapping from asset ID to its details
    mapping(uint256 => DigitalAsset) public assets;
    
    // Mapping to track assets owned by each address
    mapping(address => uint256[]) public ownedAssets;
    
    // Mapping to track assets created by each address
    mapping(address => uint256[]) public createdAssets;
    
    // Counter for generating unique asset IDs
    uint256 private _assetIdCounter;
    
    // Events
    event AssetRegistered(uint256 indexed assetId, address indexed creator, bytes32 contentHash);
    event AssetTransferred(uint256 indexed assetId, address indexed from, address indexed to);
    event AssetMetadataUpdated(uint256 indexed assetId, string name, string description, string assetURI);
    event UserAuthorized(uint256 indexed assetId, address indexed user);
    event UserDeauthorized(uint256 indexed assetId, address indexed user);
    
    /**
     * @dev Register a new digital asset
     * @param _name Name of the asset
     * @param _description Description of the asset
     * @param _assetURI URI pointing to the asset or its metadata
     * @param _contentHash Hash of the digital content
     * @param _isTransferable Boolean indicating if the asset can be transferred
     * @return Asset ID of the newly registered asset
     */
    function registerAsset(
        string memory _name,
        string memory _description,
        string memory _assetURI,
        bytes32 _contentHash,
        bool _isTransferable
    ) public returns (uint256) {
        uint256 assetId = _assetIdCounter++;
        
        DigitalAsset storage newAsset = assets[assetId];
        newAsset.name = _name;
        newAsset.description = _description;
        newAsset.assetURI = _assetURI;
        newAsset.contentHash = _contentHash;
        newAsset.creationTime = block.timestamp;
        newAsset.creator = msg.sender;
        newAsset.currentOwner = msg.sender;
        newAsset.isTransferable = _isTransferable;
        newAsset.lastTransferTime = block.timestamp;
        
        // Add to the lists of owned and created assets
        ownedAssets[msg.sender].push(assetId);
        createdAssets[msg.sender].push(assetId);
        
        emit AssetRegistered(assetId, msg.sender, _contentHash);
        
        return assetId;
    }
    
    /**
     * @dev Transfer ownership of an asset
     * @param _assetId ID of the asset to transfer
     * @param _to Address of the new owner
     */
    function transferAsset(uint256 _assetId, address _to) public {
        require(_to != address(0), "Cannot transfer to zero address");
        require(_assetId < _assetIdCounter, "Asset does not exist");
        require(assets[_assetId].currentOwner == msg.sender, "Not the owner of the asset");
        require(assets[_assetId].isTransferable, "Asset is not transferable");
        
        address previousOwner = assets[_assetId].currentOwner;
        assets[_assetId].currentOwner = _to;
        assets[_assetId].lastTransferTime = block.timestamp;
        
        // Update the ownership records
        _removeFromOwnedAssets(previousOwner, _assetId);
        ownedAssets[_to].push(_assetId);
        
        emit AssetTransferred(_assetId, previousOwner, _to);
    }
    
    /**
     * @dev Update metadata of an asset
     * @param _assetId ID of the asset to update
     * @param _name Updated name
     * @param _description Updated description
     * @param _assetURI Updated URI
     */
    function updateAssetMetadata(
        uint256 _assetId,
        string memory _name,
        string memory _description,
        string memory _assetURI
    ) public {
        require(_assetId < _assetIdCounter, "Asset does not exist");
        require(assets[_assetId].currentOwner == msg.sender, "Not the owner of the asset");
        
        assets[_assetId].name = _name;
        assets[_assetId].description = _description;
        assets[_assetId].assetURI = _assetURI;
        
        emit AssetMetadataUpdated(_assetId, _name, _description, _assetURI);
    }
    
    /**
     * @dev Authorize a user to access an asset
     * @param _assetId ID of the asset
     * @param _user Address of the user to authorize
     */
    function authorizeUser(uint256 _assetId, address _user) public {
        require(_assetId < _assetIdCounter, "Asset does not exist");
        require(assets[_assetId].currentOwner == msg.sender, "Not the owner of the asset");
        require(_user != address(0), "Cannot authorize zero address");
        
        assets[_assetId].authorizedUsers[_user] = true;
        
        emit UserAuthorized(_assetId, _user);
    }
    
    /**
     * @dev Revoke authorization for a user
     * @param _assetId ID of the asset
     * @param _user Address of the user to deauthorize
     */
    function deauthorizeUser(uint256 _assetId, address _user) public {
        require(_assetId < _assetIdCounter, "Asset does not exist");
        require(assets[_assetId].currentOwner == msg.sender, "Not the owner of the asset");
        
        assets[_assetId].authorizedUsers[_user] = false;
        
        emit UserDeauthorized(_assetId, _user);
    }
    
    /**
     * @dev Check if a user is authorized to access an asset
     * @param _assetId ID of the asset
     * @param _user Address of the user to check
     * @return Boolean indicating authorization status
     */
    function isUserAuthorized(uint256 _assetId, address _user) public view returns (bool) {
        require(_assetId < _assetIdCounter, "Asset does not exist");
        
        // Owner and creator are always authorized
        if (_user == assets[_assetId].currentOwner || _user == assets[_assetId].creator) {
            return true;
        }
        
        return assets[_assetId].authorizedUsers[_user];
    }
    
    /**
     * @dev Get asset metadata
     * @param _assetId ID of the asset
     * @return name Name of the asset
     * @return description Description of the asset
     * @return assetURI URI pointing to the asset or its metadata
     * @return contentHash Hash of the digital content
     * @return creationTime Time when the asset was created
     * @return creator Address of the creator
     * @return currentOwner Address of the current owner
     * @return isTransferable Boolean indicating if the asset can be transferred
     * @return lastTransferTime Time of the last ownership transfer
     */
    function getAssetDetails(uint256 _assetId) public view returns (
        string memory name,
        string memory description,
        string memory assetURI,
        bytes32 contentHash,
        uint256 creationTime,
        address creator,
        address currentOwner,
        bool isTransferable,
        uint256 lastTransferTime
    ) {
        require(_assetId < _assetIdCounter, "Asset does not exist");
        
        DigitalAsset storage asset = assets[_assetId];
        return (
            asset.name,
            asset.description,
            asset.assetURI,
            asset.contentHash,
            asset.creationTime,
            asset.creator,
            asset.currentOwner,
            asset.isTransferable,
            asset.lastTransferTime
        );
    }
    
    /**
     * @dev Get all assets owned by an address
     * @param _owner Address of the owner
     * @return Array of asset IDs owned by the address
     */
    function getOwnedAssets(address _owner) public view returns (uint256[] memory) {
        return ownedAssets[_owner];
    }
    
    /**
     * @dev Get all assets created by an address
     * @param _creator Address of the creator
     * @return Array of asset IDs created by the address
     */
    function getCreatedAssets(address _creator) public view returns (uint256[] memory) {
        return createdAssets[_creator];
    }
    
    /**
     * @dev Verify if a content hash matches an asset
     * @param _assetId ID of the asset
     * @param _contentHash Hash to verify
     * @return Boolean indicating if the hash matches
     */
    function verifyContentHash(uint256 _assetId, bytes32 _contentHash) public view returns (bool) {
        require(_assetId < _assetIdCounter, "Asset does not exist");
        return assets[_assetId].contentHash == _contentHash;
    }
    
    /**
     * @dev Get the total number of registered assets
     * @return Total number of assets
     */
    function getTotalAssets() public view returns (uint256) {
        return _assetIdCounter;
    }
    
    /**
     * @dev Helper function to remove an asset from the owned assets array
     * @param _owner Address of the owner
     * @param _assetId ID of the asset to remove
     */
    function _removeFromOwnedAssets(address _owner, uint256 _assetId) private {
        uint256[] storage ownerAssets = ownedAssets[_owner];
        for (uint256 i = 0; i < ownerAssets.length; i++) {
            if (ownerAssets[i] == _assetId) {
                // Replace with the last element and pop
                ownerAssets[i] = ownerAssets[ownerAssets.length - 1];
                ownerAssets.pop();
                break;
            }
        }
    }
}
