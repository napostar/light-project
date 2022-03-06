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
  - Each URI reflects the current state and is dynamically generated
  - Each NFT owner can update the state of their NFTs
  - The "Genesis" Light (id=0) state can be changed by anyone, for a variable fee.
  - An event is generated whenever the state is changed (for the dApp)
  - Support for opensea.io meta transactions and marketplace proxy
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
        string name;
        string description;
        bool lightState;
    }
    
    mapping(uint256 => _nftData) public assetData;
    uint256 public constant MAX_MINT = 10000;
    uint256 public genesisFee = 0.1 ether;
    string private _contractURI;
    
    event LightToggled(uint256 indexed tokenId, bool state);
    
    constructor() ERC721("TheLightProject", "LIGHT") {
      _initializeEIP712("TheLightProject");
    }

    /**
     * Description of function
     */
    function safeMint(address to, string memory uri, string memory name, string memory description) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId < MAX_MINT, "Reached max mint limit");
        
        //mint token
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenData(tokenId, uri, name, description);
    }
    
    /**
     * Description of function
     */
    function _setTokenData(uint256 tokenId, string memory uri, string memory name, string memory description) internal {
      _setTokenURI(tokenId, uri); 
      assetData[tokenId].name = name;
      assetData[tokenId].description = description;
      assetData[tokenId].lightState = false;
    }
    
    /**
     * Description of function
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
                  '{"name":"',
                  assetData[tokenId].name,
                  '", "description":"',
                  assetData[tokenId].description,
                  '", "image": "',
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
     * Description of function
     */
    function toggleLight(uint256 tokenId) public {
        require(_exists(tokenId), "Interaction attempted for nonexistent token");
        require(msg.sender == ownerOf(tokenId), "Interaction only allowed by NFT owner");
        
        _toggle(tokenId);
       
    }
    
    /**
     * Description of function
     */
    function _toggle(uint256 tokenId) private {
         //toggle the light's state
        assetData[tokenId].lightState = !assetData[tokenId].lightState;
        
        //generate the light toggle event
        emit LightToggled(tokenId,  assetData[tokenId].lightState);
    }
    
    /**
     * Description of function
     */
    function toggleGenesis() public payable{
        require(_exists(0), "Interaction attempted for nonexistent token");
        require(msg.value >= genesisFee, "Insufficient payment");
        
        _toggle(0);
    }

    /**
     * Description of function
     */
    function setGenesisFee(uint256 amt) public onlyOwner{
        genesisFee = amt;
    }
    
    /**
     * Description of function
     */
    function getGenesisFee() public view returns (uint){
        return genesisFee;
    }
    
    /**
     * Description of function
     */
    function ownerWithdraw(address to) public onlyOwner{
        uint amount = address(this).balance;
        payable(to).transfer(amount);
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