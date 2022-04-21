// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/*
                                     ----------
                                   /            \
                                 /                \
                                |                  |
                                |       8888       |
                                |      888888      |
                                 \      |  |      / 
                                   \    |  |     /
                                    \   |  |   /
                                     |--------|
                                     |--  -- -|
                                     | - --- -|
                                      \------/
                                       \0000/
                                   
  _______ _            _      _       _     _     _____           _           _   
 |__   __| |          | |    (_)     | |   | |   |  __ \         (_)         | |  
    | |  | |__   ___  | |     _  __ _| |__ | |_  | |__) | __ ___  _  ___  ___| |_ 
    | |  | '_ \ / _ \ | |    | |/ _` | '_ \| __| |  ___/ '__/ _ \| |/ _ \/ __| __|
    | |  | | | |  __/ | |____| | (_| | | | | |_  | |   | | | (_) | |  __/ (__| |_ 
    |_|  |_| |_|\___| |______|_|\__, |_| |_|\__| |_|   |_|  \___/| |\___|\___|\__|
                                 __/ |                          _/ |              
                                |___/                          |__/               

The Light Project, an exploration of dynamic NFTs, where *you* are in control!  Let's go beyond boring basic static content!

http://thelightproject.io

Goals of this Contract:
-----------------------
  - Contract owner can mint upto MAX_MINT NFTs with unique URIs
  - Each URI reflects the light's current state
  - Each NFT owner can update the state of their NFTs
  - Each NFT's state can be changed by anyone, for a variable fee, payable to the NFT's owner
  - An event is generated whenever the state is changed (for the dApp)
  - Support for opensea.io meta-transactions and marketplace proxy
*/

import "@openzeppelin/contracts@4.3.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.3.2/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.3.2/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@4.3.2/access/Ownable.sol";
import "@openzeppelin/contracts@4.3.2/utils/Counters.sol";
import "@openzeppelin/contracts@4.3.2/utils/Strings.sol";
import 'base64-sol/base64.sol';
import 'OpenSea.sol';

contract LightProj is ERC721, ERC721URIStorage, ERC721Enumerable, ContextMixin, NativeMetaTransaction, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    
    struct _nftData {
        bool lightState;
        uint256 fee;
        uint256 balance;
    }
    
    mapping(uint256 => _nftData) public assetData;
    uint256 public constant MAX_MINT = 1000;
    string private _contractURI;
    
    event LightToggled(uint256 indexed tokenId, bool state);
    
    constructor() ERC721("TheLightProject", "LITE") {
      _initializeEIP712("TheLightProject");
    }

    /**
     * Mint new NFT tokens
     */
    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId < MAX_MINT, "Reached max mint limit");
        
        //mint token
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri); 
        assetData[tokenId].lightState = false;
        assetData[tokenId].fee = 0.1 ether;
        assetData[tokenId].balance = 0;
    }
    
    /**
     * Returns the token's URI
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory)
    {
      require(_exists(tokenId), "URI requested of nonexistent token");
      //return a dynamic data uri
      return
        string(
          abi.encodePacked(
            'data:application/json;base64,',
            Base64.encode(
              bytes(
                abi.encodePacked(
                  '{"image": "',
                  super.tokenURI(tokenId),
                  assetData[tokenId].lightState ? '/on':'/off',
                  '", "external_url":"https://thelightproject.io/asset/',
                  Strings.toString(tokenId),
                  '",',
                  '"attributes": [{"trait_type":"Light", "value":"',
                  assetData[tokenId].lightState ? 'on':'off',
                  '"}]}'
                )
              )
            )
          )
        );
    }
    
    /**
     * Toggle the light state of the given token
     */
    function toggleLight(uint256 tokenId) public payable {
        require(_exists(tokenId), "Interaction attempted for nonexistent token");
        require(msg.value >= assetData[tokenId].fee, "Fee not sufficient");
         //toggle the light's state
        assetData[tokenId].lightState = !assetData[tokenId].lightState;
        assetData[tokenId].balance += msg.value;

        //generate the light toggle event
        emit LightToggled(tokenId,  assetData[tokenId].lightState);
    }
    
    /**
     * Allow NFT owners to withdraw funds from their NFT
     */
    function ownerWithdraw(address to, uint256 tokenId) public {
        require(_exists(tokenId), "Interaction attempted for nonexistent token");
        require(msg.sender == ownerOf(tokenId), "Interaction only allowed by NFT owner");
        require(assetData[tokenId].balance > 0, "No funds to transfer, empty balance");

        uint amount = assetData[tokenId].balance;
        assetData[tokenId].balance = 0; //empty balance
        payable(to).transfer(amount);
    }

    /**
     * Allow NFT owners to update their toggle fee
     */
    function updateFee(uint256 tokenId, uint256 _fee) public {
        require(_exists(tokenId), "Interaction attempted for nonexistent token");
        require(msg.sender == ownerOf(tokenId), "Interaction only allowed by NFT owner");

        assetData[tokenId].fee = _fee;
    }
    
    /**
     * Accessor for getting the fee for the specified nft via it's tokenId
     */
    function getTokenFee(uint256 tokenId) public view returns (uint256 feeAmt){
      require(_exists(tokenId), "Interaction attempted for nonexistent token");
      return assetData[tokenId].fee;
    }
    
    /**
     * Override isApprovedForAll to auto-approve open sea's proxy contract
     */
    function isApprovedForAll(address _owner, address _operator) public override view returns (bool isOperator) {
        // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }
        
        // otherwise, use the default ERC721.isApprovedForAll()
        return ERC721.isApprovedForAll(_owner, _operator);
    }
    
    /**
     * Contract URI for the opensea.io storefront-level metadata
     */
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    /**
     * Helper function to update the contract URI
     */
    function updateContractURI(string memory newURI) public onlyOwner{
        _contractURI = newURI;
    }
    
    /**
     * Required override for Solidity
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable){
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * Required override for Solidity
     */
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /**
     * Required override
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool){
        return super.supportsInterface(interfaceId);
    }

    /**
     * For Meta Transactions this is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     */
    function _msgSender() internal override view  returns (address sender){
        return ContextMixin.msgSender();
    }
}