// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "hardhat/console.sol";

interface IERC721{
     function ownerOf(uint256 tokenId) external view returns (address owner);

     function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function tokenURI(uint256 id) external view returns (string memory URI);
    function setRootURI(string memory rootURI) external;

    function mint(
        address to,
        string memory URI,
        uint256 tokenID
    ) external;
}

contract ticketManager{
    address CONTRACT;
    address _ticketContract;
    IERC721 _ticketFactory;

    //Number of Tickets Minted
    uint256 _mintedTickets;
    //Number of Tickets Purchased
    uint256 _purchasedTickets;
    //Address of Who Deployed Smart Contract
    address  _owner;
    //Total Revenue
    uint256 _totalRevenue;
    //Tiers
    mapping(string => int) public _allTiers;
    // How much each ticket at each tier costs
    mapping(string => uint256) public _tierPricing;
    // How many tickets are still available in each tier
    mapping(string => int) public _tierCount;
    // Maps Tiers To All Tickets IDs Available
    mapping(string => uint256[]) _tierToTickets;
    //Event Name
    string _eventName;

    modifier onlyOwner {
      require(msg.sender == _owner);
      _;
   }

    constructor(string memory eventName, address ticketContract) {
        _owner = msg.sender;
        CONTRACT = address(this);
        _eventName = eventName;
        _ticketContract = ticketContract;
        _ticketFactory = IERC721(ticketContract);
    }

    receive() external payable {
        console.log("Received Funds");
    }

    // Mint Tokens
    function mintTicket(string memory tier, string memory URI, uint256 id) public onlyOwner{
        require(_allTiers[tier] == 1, "Tier Has Not Been Initialized");
        _ticketFactory.mint(CONTRACT, URI, id);
        _tierCount[tier] += 1;
        _tierToTickets[tier].push(id);
    }

    //Allows Anyone To Buy a Ticket As Long As They Are Available
    function purchaseTicket(string memory tier) public payable {
        require(msg.value >= _tierPricing[tier], "Insufficient Funds");
        require(_tierCount[tier] > 0, "No More Tickets Available");
        //Transfer Funds
        bool checkTransfer;
        bytes memory data;

        (checkTransfer, data) = payable(msg.sender).call{value: msg.value - _tierPricing[tier]}("");
        require(checkTransfer, "Couldn't send excess funds back");

        console.log("Balance of Contract After Purchase", CONTRACT.balance);

        uint256[] memory ticketIDs = _tierToTickets[tier];
        uint256 ticketID = ticketIDs[ticketIDs.length - 1];
        _tierToTickets[tier].pop();

        console.log(_ticketFactory.ownerOf(ticketID), "Ticket Owner Before Transfer");
        _ticketFactory.safeTransferFrom(CONTRACT, msg.sender, ticketID);
        console.log(_ticketFactory.ownerOf(ticketID), "Ticket Owner After Transfer");


        _totalRevenue += _tierPricing[tier];
        _tierCount[tier] -= 1;
        _purchasedTickets += 1;

    }

    //Allows the Owner To Add A Tier
    function addTier(string memory tier, uint256 cost) public onlyOwner{
        require(_allTiers[tier] == 0, "Tier Has Already Been Created");
        _allTiers[tier] = 1;
        _tierPricing[tier] = cost;
    }

    //Modify The Cost of Tickets of An Existing Tier
    function modifyCostTier(string memory tier, uint256 newPrice) public onlyOwner{
        require(_allTiers[tier] == 1, "Tier Has Not Been Initialized");
        require(_tierCount[tier] != 0, "Ticket Count is 0");
        _tierPricing[tier] = newPrice;
    }

    //Reduce The Number of Tickets of An Existing Tier
    function modifyCountTier(string memory tier, int newCount) public onlyOwner{
        require(_allTiers[tier] == 1, "Tier Has Not Been Initialized");
        require(_tierCount[tier] != 0, "Ticket Count is 0");
        require(_tierCount[tier] > newCount, "Can Only Reduce Count");
        _tierCount[tier] = newCount;
    }

    //Sends All Funds To The Owner of The Smart Contract
    function widthrawRevenue() public onlyOwner{
        bool checkTransfer;
        bytes memory data;
        (checkTransfer, data) = payable(_owner).call{value: CONTRACT.balance}("");
        require(checkTransfer, "Failed To Send Funds To Owner");
    }

}
