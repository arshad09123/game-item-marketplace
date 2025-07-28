
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

contract GamingMarketplaceDApp {
    
    struct GameItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address seller;
        uint256 price;
        string gameName;
        string itemName;
        bool isActive;
    }
    
    mapping(uint256 => GameItem) public gameItems;
    mapping(address => uint256[]) public userListings;
    mapping(address => uint256) public sellerEarnings;
    
    uint256 public nextItemId = 1;
    uint256 public platformFee = 200; // 2% fee (200/10000)
    address public owner;
    
    event ItemListed(
        uint256 indexed itemId,
        address indexed seller,
        address nftContract,
        uint256 tokenId,
        uint256 price,
        string gameName,
        string itemName
    );
    
    event ItemPurchased(
        uint256 indexed itemId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );
    
    event ItemDelisted(uint256 indexed itemId);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // 1. List a gaming NFT for sale
    function listGameItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        string memory gameName,
        string memory itemName
    ) external {
        require(price > 0, "Price must be greater than 0");
        
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "You don't own this NFT");
        require(
            nft.getApproved(tokenId) == address(this) || 
            nft.isApprovedForAll(msg.sender, address(this)),
            "Contract not approved to transfer NFT"
        );
        
        uint256 itemId = nextItemId++;
        
        gameItems[itemId] = GameItem({
            itemId: itemId,
            nftContract: nftContract,
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            gameName: gameName,
            itemName: itemName,
            isActive: true
        });
        
        userListings[msg.sender].push(itemId);
        
        emit ItemListed(itemId, msg.sender, nftContract, tokenId, price, gameName, itemName);
    }
    
    // 2. Purchase a gaming item
    function purchaseItem(uint256 itemId) external payable {
        GameItem storage item = gameItems[itemId];
        require(item.isActive, "Item not available");
        require(msg.value >= item.price, "Insufficient payment");
        require(msg.sender != item.seller, "Cannot buy your own item");
        
        item.isActive = false;
        
        // Calculate platform fee
        uint256 fee = (item.price * platformFee) / 10000;
        uint256 sellerAmount = item.price - fee;
        
        // Transfer NFT to buyer
        IERC721(item.nftContract).transferFrom(item.seller, msg.sender, item.tokenId);
        
        // Update seller earnings
        sellerEarnings[item.seller] += sellerAmount;
        sellerEarnings[owner] += fee;
        
        // Refund excess payment
        if (msg.value > item.price) {
            payable(msg.sender).transfer(msg.value - item.price);
        }
        
        emit ItemPurchased(itemId, msg.sender, item.seller, item.price);
    }
    
    // 3. Remove item from marketplace
    function delistItem(uint256 itemId) external {
        GameItem storage item = gameItems[itemId];
        require(item.seller == msg.sender, "Only seller can delist");
        require(item.isActive, "Item already inactive");
        
        item.isActive = false;
        
        emit ItemDelisted(itemId);
    }
    
    // 4. Withdraw earnings from sales
    function withdrawEarnings() external {
        uint256 earnings = sellerEarnings[msg.sender];
        require(earnings > 0, "No earnings to withdraw");
        
        sellerEarnings[msg.sender] = 0;
        payable(msg.sender).transfer(earnings);
    }
    
    // 5. Get all active items for browsing
    function getActiveItems(uint256 limit, uint256 offset) external view returns (GameItem[] memory) {
        uint256 activeCount = 0;
        
        // Count active items
        for (uint256 i = 1; i < nextItemId; i++) {
            if (gameItems[i].isActive) {
                activeCount++;
            }
        }
        
        if (activeCount == 0 || offset >= activeCount) {
            return new GameItem[](0);
        }
        
        uint256 returnCount = limit;
        if (offset + limit > activeCount) {
            returnCount = activeCount - offset;
        }
        
        GameItem[] memory activeItems = new GameItem[](returnCount);
        uint256 currentIndex = 0;
        uint256 foundCount = 0;
        
        for (uint256 i = 1; i < nextItemId && currentIndex < returnCount; i++) {
            if (gameItems[i].isActive) {
                if (foundCount >= offset) {
                    activeItems[currentIndex] = gameItems[i];
                    currentIndex++;
                }
                foundCount++;
            }
        }
        
        return activeItems;
    }
    
    // 6. Get user's listed items
    function getUserListings(address user) external view returns (uint256[] memory) {
        return userListings[user];
    }
    
    // Admin function to update platform fee
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 500, "Fee cannot exceed 5%"); // Max 5% fee
        platformFee = newFee;
    }
}
