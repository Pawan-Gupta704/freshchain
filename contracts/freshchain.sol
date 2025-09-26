// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title FreshChain
 * @dev A smart contract for supply chain transparency and food freshness tracking
 * @author FreshChain Team
 */
contract FreshChain {
    
    // Events
    event ProductRegistered(uint256 indexed productId, address indexed producer, string productName);
    event ProductTransferred(uint256 indexed productId, address indexed from, address indexed to, uint256 timestamp);
    event FreshnessUpdated(uint256 indexed productId, uint8 freshnessScore, uint256 timestamp);
    
    // Structs
    struct Product {
        uint256 id;
        string name;
        string category;
        address producer;
        address currentOwner;
        uint256 productionDate;
        uint256 expiryDate;
        uint8 freshnessScore; // 1-100 scale
        bool isActive;
        string[] locations; // Track journey
    }
    
    struct Transfer {
        address from;
        address to;
        uint256 timestamp;
        string location;
    }
    
    // State variables
    mapping(uint256 => Product) public products;
    mapping(uint256 => Transfer[]) public productTransfers;
    mapping(address => bool) public authorizedUpdaters;
    
    uint256 private nextProductId;
    address public owner;
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }
    
    modifier onlyProductOwner(uint256 _productId) {
        require(products[_productId].currentOwner == msg.sender, "Only product owner can call this function");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedUpdaters[msg.sender] || msg.sender == owner, "Not authorized to update freshness");
        _;
    }
    
    modifier productExists(uint256 _productId) {
        require(products[_productId].isActive, "Product does not exist or is inactive");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        nextProductId = 1;
        authorizedUpdaters[msg.sender] = true;
    }
    
    /**
     * @dev Core Function 1: Register a new product in the supply chain
     * @param _name Product name
     * @param _category Product category (e.g., "Fruits", "Vegetables", "Dairy")
     * @param _productionDate Unix timestamp of production date
     * @param _expiryDate Unix timestamp of expiry date
     * @param _initialLocation Initial location of the product
     */
    function registerProduct(
        string memory _name,
        string memory _category,
        uint256 _productionDate,
        uint256 _expiryDate,
        string memory _initialLocation
    ) external returns (uint256) {
        require(_productionDate <= block.timestamp, "Production date cannot be in the future");
        require(_expiryDate > _productionDate, "Expiry date must be after production date");
        require(bytes(_name).length > 0, "Product name cannot be empty");
        
        uint256 productId = nextProductId++;
        
        // Initialize locations array
        string[] memory locations = new string[](1);
        locations[0] = _initialLocation;
        
        products[productId] = Product({
            id: productId,
            name: _name,
            category: _category,
            producer: msg.sender,
            currentOwner: msg.sender,
            productionDate: _productionDate,
            expiryDate: _expiryDate,
            freshnessScore: 100, // Start with maximum freshness
            isActive: true,
            locations: locations
        });
        
        emit ProductRegistered(productId, msg.sender, _name);
        return productId;
    }
    
    /**
     * @dev Core Function 2: Transfer product ownership and update location
     * @param _productId ID of the product to transfer
     * @param _newOwner Address of the new owner
     * @param _newLocation New location of the product
     */
    function transferProduct(
        uint256 _productId,
        address _newOwner,
        string memory _newLocation
    ) external productExists(_productId) onlyProductOwner(_productId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != products[_productId].currentOwner, "Cannot transfer to current owner");
        require(bytes(_newLocation).length > 0, "Location cannot be empty");
        
        address previousOwner = products[_productId].currentOwner;
        products[_productId].currentOwner = _newOwner;
        products[_productId].locations.push(_newLocation);
        
        // Record transfer history
        productTransfers[_productId].push(Transfer({
            from: previousOwner,
            to: _newOwner,
            timestamp: block.timestamp,
            location: _newLocation
        }));
        
        emit ProductTransferred(_productId, previousOwner, _newOwner, block.timestamp);
    }
    
    /**
     * @dev Core Function 3: Update product freshness score
     * @param _productId ID of the product
     * @param _freshnessScore New freshness score (1-100)
     */
    function updateFreshness(
        uint256 _productId,
        uint8 _freshnessScore
    ) external productExists(_productId) onlyAuthorized {
        require(_freshnessScore >= 1 && _freshnessScore <= 100, "Freshness score must be between 1 and 100");
        require(block.timestamp <= products[_productId].expiryDate, "Cannot update expired product");
        
        products[_productId].freshnessScore = _freshnessScore;
        
        emit FreshnessUpdated(_productId, _freshnessScore, block.timestamp);
    }
    
    // Additional utility functions
    
    /**
     * @dev Get complete product information
     * @param _productId ID of the product
     */
    function getProductInfo(uint256 _productId) 
        external 
        view 
        productExists(_productId) 
        returns (
            string memory name,
            string memory category,
            address producer,
            address currentOwner,
            uint256 productionDate,
            uint256 expiryDate,
            uint8 freshnessScore,
            string[] memory locations
        ) 
    {
        Product memory product = products[_productId];
        return (
            product.name,
            product.category,
            product.producer,
            product.currentOwner,
            product.productionDate,
            product.expiryDate,
            product.freshnessScore,
            product.locations
        );
    }
    
    /**
     * @dev Get transfer history for a product
     * @param _productId ID of the product
     */
    function getTransferHistory(uint256 _productId) 
        external 
        view 
        productExists(_productId) 
        returns (Transfer[] memory) 
    {
        return productTransfers[_productId];
    }
    
    /**
     * @dev Check if product is expired
     * @param _productId ID of the product
     */
    function isProductExpired(uint256 _productId) 
        external 
        view 
        productExists(_productId) 
        returns (bool) 
    {
        return block.timestamp > products[_productId].expiryDate;
    }
    
    /**
     * @dev Add authorized freshness updater
     * @param _updater Address to authorize
     */
    function addAuthorizedUpdater(address _updater) external onlyOwner {
        require(_updater != address(0), "Invalid address");
        authorizedUpdaters[_updater] = true;
    }
    
    /**
     * @dev Remove authorized freshness updater
     * @param _updater Address to remove authorization
     */
    function removeAuthorizedUpdater(address _updater) external onlyOwner {
        authorizedUpdaters[_updater] = false;
    }
    
    /**
     * @dev Get current product count
     */
    function getTotalProducts() external view returns (uint256) {
        return nextProductId - 1;
    }
}
