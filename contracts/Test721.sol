// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "./library/KIP17Enumerable.sol";
import "./library/KIP17Metadata.sol";
import "./library/Strings.sol";

contract Test721 is KIP17Enumerable, KIP17Metadata {
    using Strings for uint256;

    constructor() KIP17Metadata("Test721", "Test721") public {
    }

    function mint(address account) public {
        _mint(account, totalSupply() + 1);
    }

    function _baseURI() internal view returns (string memory) {
        return "http://tiktok.fandom.io/api/v0/nft/token/";
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "KIP17Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0
        ? string(abi.encodePacked(baseURI, tokenId.toString()))
        : '';
    }
}