// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/*
The Light Project, an exploration of Dynamic NFTs.  Let's go beyond basic static content!

Goals of this Contract:
  - 
*/

import "@openzeppelin/contracts@4.3.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.3.2/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.3.2/access/Ownable.sol";
import "@openzeppelin/contracts@4.3.2/utils/Counters.sol";

contract PayableLight is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    mapping(uint256 => bool) private _lightMap;
    mapping(uint256 => uint256) private _lightBalance;
    mapping(uint256 => uint256) private _lightTogglePrice; //price in wei?
    uint256 private _ownerRoyalties;
    uint256 private _MAXMINT;
    uint256 private _defaultPrice;
    
    constructor() ERC721("LightProj", "LIGHT") {
        _ownerRoyalties = 0;
        _MAXMINT = 10000;
        _defaultPrice = 0.5 ether;
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        _lightMap[tokenId] = false; //default light to the off state
        _lightBalance[tokenId] = 0; //default balance to zero
        _lightTogglePrice[tokenId] = _defaultPrice; 
    }
    
    /*
    //make a baseURI and then this will be used instead of the per-token URI.
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://HASH/";
    }*/
    
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory)
    {
        string memory stateStr = _lightMap[tokenId] ? "/on" : "/off" ;
        return string(abi.encodePacked(super.tokenURI(tokenId), stateStr));
    }
    
    //send an event whenever the light is toggled, for having in the 
    event LightToggled(address, uint256, bool);
    function toggleLight(uint256 tokenId) public payable{
        require(_exists(tokenId), "Toggle attempted for nonexistent token");
        //TODO check enough payment was sent
        
        //update balance for specific NFT
        uint256 ownerRoyalty = msg.value / 100;
        _ownerRoyalties += ownerRoyalty;
        _lightBalance[tokenId] += msg.value - ownerRoyalty;
        
        if(_lightMap[tokenId])
            _lightMap[tokenId] = false;
        else
            _lightMap[tokenId] = true;
        emit LightToggled(msg.sender, tokenId,  _lightMap[tokenId]);
    }
    
    function royaltyBalance(uint256 tokenId) public view returns(uint256){
        return _lightBalance[tokenId];
    }
    
    function ownerRoyaltyBalance()public view returns(uint256){
        return _ownerRoyalties;
    }
    
    //provide a way for owners of an NFT to withrdraw their toggle royalties
    function withdraw(uint256 tokenId) public{
        require(_exists(tokenId), "Withdraw for nonexistent token");
        //TODO check sender is owner of tokenId
        //TODO Check there is balance to withdraw
        
        uint amount = _lightBalance[tokenId];
        _lightBalance[tokenId] = 0;
        payable(msg.sender).transfer(amount);
    }
    
    function ownerWithdraw() public onlyOwner{
        //TODO check there is a balance to withdraw
        
        uint amount = _ownerRoyalties;
        _ownerRoyalties = 0;
        payable(msg.sender).transfer(amount);
    }
    
    // Function to deposit Ether into this contract.
    // Call this function along with some Ether.
    // The balance of this contract will be automatically updated.
    function deposit() public payable {}
    
    function contractBalance() public view returns (uint){
        return address(this).balance;
    }
    
    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

}
