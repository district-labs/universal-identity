// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { Document } from "../src/Document.sol";
import { Identifier } from "../src/Identifier.sol";
import { UniversalResolver } from "../src/UniversalResolver.sol";

contract Deploy is BaseScript {
    uint256 private deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public returns (Document document, UniversalResolver resolver) {
        vm.startBroadcast(deployerPrivateKey);
        // Deploy document contract
        document = new Document();

        // Deploy identifier implementation
        Identifier identifierImplementation = new Identifier();

        // Deploy Universal Resolver
        resolver = new UniversalResolver(msg.sender, address(identifierImplementation), vm.envString("RESOLVER_URL"));
        vm.stopBroadcast();
    }
}
