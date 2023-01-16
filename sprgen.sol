// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract SpearheadGenesis is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Address for address;
    using Strings for uint256;

    bytes32 public merkleRoot;
    mapping(address => bool) public whitelistClaimed;

    Counters.Counter private _tokenIdCounter;
    IERC20 public usdc;
    
    string public uriPrefix = '';
    string public uriSuffix = '.json';
    string public hiddenMetadataUri;
  
    uint256 public cost;
    uint256 public rate;
    uint256 public maxSupply;
    uint256 public maxMintAmountPerTx;
    uint256 public totalIssued;
    uint256 public totalMinted;

    bool public paused = true;
    bool public whitelistMintEnabled = false;
    bool public revealed = false;

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _cost,
        uint256 _maxSupply,
        uint256 _maxMintAmountPerTx,
        address _usdcAddress,
        string memory _hiddenMetadataUri
    ) ERC721(_tokenName, _tokenSymbol) {
        setCost(_cost);
        maxSupply = _maxSupply;
        setMaxMintAmountPerTx(_maxMintAmountPerTx);
        setHiddenMetadataUri(_hiddenMetadataUri);
        usdc = IERC20(_usdcAddress);
        rate = _cost * 10 ** 6;
    }

    modifier mintCompliance(uint256 _mintAmount) {
        require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, 'Invalid Mint Amount!');
        require(totalMinted + _mintAmount <= maxSupply, 'Mint Amount Exceeds Supply!');
        require(!paused, "Public Sale is Not Live!");
        require(_mintAmount <= remainingIssuedUnsoldLeft(), "Not Enough Tokens Issued!");
        _;
    }

    // Public Sale Minting Functionality
    function mint(uint256 _mintAmount) public mintCompliance(_mintAmount) {
        _batchMint(_mintAmount);
    }

    // Owner Minting Functionality
    function ownerMint(uint256 _mintAmount) external onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        totalMinted += _mintAmount;
        for (uint i = 1; i <= _mintAmount; i++) {
        _safeMint(msg.sender, tokenId + i);
        }
    }

    // Batch Mint Functionality (Primary)
    function _batchMint(uint256 number) internal {
        require(msg.value >= rate * number, "Transaction Value Too Low!");
        usdc.transferFrom(msg.sender, address(this), rate);
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        totalMinted += number;
        for (uint i = 1; i <= number; i++) {
        _safeMint(msg.sender, tokenId + i);
        }
    }

    // Number of Issued NFTs Remaining To Mint
    function remainingIssuedUnsoldLeft() public view returns (uint256) {
        return totalIssued - totalMinted;
    }

    // Issue Number of NFTs Available To Mint
    function issueForSale(uint256 number) external onlyOwner {
        require(number <= remainingSupplyToIssue(), "Not Enough Tokens Remaining");
        totalIssued += number;
    }

    // Number of NFTs Remaining That Can Be Issued
    function remainingSupplyToIssue() public view returns (uint256) {
        return maxSupply - totalIssued;
    }

    // Number of NFTs Remaining Out of Total Collection
    function remainingSupply() external view returns (uint256) {
        return maxSupply - totalMinted;
    }

    function whitelistMint(uint256 _mintAmount, bytes32[] calldata _merkleProof) public payable mintCompliance(_mintAmount) {
    // Verify whitelist requirements
        require(whitelistMintEnabled, 'The whitelist sale is not enabled!');
        require(!whitelistClaimed[_msgSender()], 'Address already claimed!');
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), 'Invalid proof!');

        whitelistClaimed[_msgSender()] = true;
        _safeMint(_msgSender(), _mintAmount);
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
    require(_exists(_tokenId), 'ERC721Metadata: URI query for nonexistent token');

    if (revealed == false) {
      return hiddenMetadataUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
        : '';
  }

    function setCost(uint256 _cost) public onlyOwner {
    cost = _cost;
    }

    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyOwner {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setWhitelistMintEnabled(bool _state) public onlyOwner {
        whitelistMintEnabled = _state;
    }

    function reveal() public onlyOwner {
        revealed = true;
    }

    function withdraw() public onlyOwner nonReentrant {
    // This will transfer the remaining contract balance to the owner.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
        (bool os, ) = payable(owner()).call{value: address(this).balance}('');
        require(os);
    // =============================================================================
    }

    function withdrawUSDC() public payable onlyOwner nonReentrant {
        usdc.transfer(msg.sender, usdc.balanceOf(address(this)));
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }
 
}
