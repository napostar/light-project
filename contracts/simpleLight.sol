// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract light is ERC721, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => bool) private _lightMap;
    
    constructor() ERC721("LightProj", "LIGHT") {}

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://HASH";
    }

    function safeMint(address to) public onlyOwner {
       uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _lightMap[curCounterVal] = false; //default light to the off state
    }
    // ipfs://QmVFiyBbM7zZa1hWv4W5CjyPKMHJC9gKr1Hg1RzuzWcQS7/0
    

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        string memory baseURI = super.tokenURI(tokenId);
        string memory stateStr = _lightMap[tokenId] ? "1" : "0" ;
        return string(abi.encodePacked(baseURI, stateStr));
    }
    
    event LightToggled(address, bool);
    function toggleLight(uint256 tokenId) public payable{
        //solhint-disable-next-line max-line-length
        require(_isApprovedSwitcher(_msgSender(), tokenId), "ERC721: switch caller is not owner nor approved");
        
        if(_lightMap[tokenId])
            _lightMap[tokenId] = false;
        else
            _lightMap[tokenId] = true;
        emit LightToggled(msg.sender, _lightMap[tokenId]);
    }
    
    function getLight(uint256 tokenId) public view returns (bool){
        return _lightMap[tokenId];
    }
    
    /**
     * @dev Returns whether `switcher` is allowed to manage `tokenId`. If the light is unlocked, anyone can switch it.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedSwitcher(address switcher, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (switcher == owner || getApproved(tokenId) == switcher || isApprovedForAll(owner, switcher) || _lightLocked[tokenId] == false );
    }
    
    /**
     * @dev Sets the state of the lock. When set TRUE, only the token owner or approved can toggle the light state.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function setLightLockState(uint256 tokenId, bool state) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _lightLocked[tokenId] = state;
    }
    
    function withdraw(address payable to) public onlyOwner returns (bool) {
        require(address(this).balance > 0, "There are no funds to withdraw.");
        to.transfer(address(this).balance);
        return true;
    }
    
    // Function to deposit Ether into this contract.
    // Call this function along with some Ether.
    // The balance of this contract will be automatically updated.
    function deposit() public payable {}
    
    function contractBalance() public view returns (uint){
        return address(this).balance;
    }
}
