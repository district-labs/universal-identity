// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract Document {
    using Strings for uint256;
    using Strings for address;

    function generate(address router, address account) public view returns (string memory) {
        string memory did = string(
            abi.encodePacked(
                "did:uis:", block.chainid.toString(), ":", router.toHexString(), ":", account.toHexString()
            )
        );

        string memory document = string(
            abi.encodePacked(
                "{",
                "\"@context\": [\"https://www.w3.org/ns/did/v1\"],",
                "\"id\": \"",
                did,
                "\",",
                "\"verificationMethod\": [{",
                "\"id\": \"",
                did,
                "#controller-key\",",
                "\"type\": \"EthEip6492\",",
                "\"controller\": \"",
                did,
                "\"",
                "}],",
                "\"authentication\": [\"",
                did,
                "#controller-key\"],",
                "\"assertionMethod\": [\"",
                did,
                "#controller-key\"]",
                "}"
            )
        );

        return document;
    }
}
