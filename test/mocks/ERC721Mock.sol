//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Mock is ERC721 {
    constructor(
        address mintTo,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {
        _safeMint(mintTo, 0);
        _safeMint(mintTo, 1);
        _safeMint(mintTo, 2);
        _safeMint(mintTo, 3);
        _safeMint(mintTo, 4);
    }
}
