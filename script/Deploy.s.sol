// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { Document } from "../src/Document.sol";
import { Identifier } from "../src/Identifier.sol";
import { Resolver } from "../src/Resolver.sol";

contract Deploy is BaseScript {
    uint256 private deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public returns (Document document, Resolver resolver) {
        vm.startBroadcast(deployerPrivateKey);
        // Deploy document contract
        document = new Document();

        // Deploy identifier and resolver implementations
        Identifier identifierImplementation = new Identifier();

        // Deploy resolver contract
        resolver = new Resolver(msg.sender, address(identifierImplementation), "http://localhost:8787");
        vm.stopBroadcast();
    }
}
