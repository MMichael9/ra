// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IRAACHousePrices.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// RAAC NFT Token Contract
contract RAAC is ERC721, ERC721Enumerable, Ownable {
    using SafeERC20 for IERC20;

    // Token and house prices interface
    IERC20 token;
    IRAACHousePrices hpInterface;

    // Current # of properties available
    uint256 public currentBatchSize = 3;

    constructor(address _token, address _housePrices) ERC721("RAAC", "RAAC") {
        token = IERC20(_token);
        hpInterface = IRAACHousePrices(_housePrices);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmPSB1k3CihUNaUav81LiaJJqka62dFDticH6MAX1L2u2Q/";
    }

    // User mints one of the RAAC Properties offered
    function mint(uint256 tokenId, uint256 amount) public {
        require(tokenId < currentBatchSize, "Invalid TokenID");
        require(amount >= hpInterface.housePrices(tokenId), "Insufficient Funds to Mint");

        // Transfer erc20 payment from user to contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Mint
        _safeMint(msg.sender, tokenId);
    }

    // Update batch size
    function addNewBatch(uint256 batchSize) public onlyOwner {
        currentBatchSize += batchSize;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}