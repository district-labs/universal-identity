// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;

import { SafeSingletonDeployer } from "safe-singleton-deployer-sol/SafeSingletonDeployer.sol";
import { BaseScript } from "./Base.s.sol";
import { Document } from "../src/Document.sol";
import { Identifier } from "../src/Identifier.sol";
import { UniversalResolver } from "../src/UniversalResolver.sol";

contract Deploy is BaseScript {
    bytes32 salt = vm.envBytes32("SALT");
    string resolverUrl = vm.envString("RESOLVER_URL");
    uint256 private deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public returns (Document document, UniversalResolver resolver) {
        vm.startBroadcast(deployerPrivateKey);
        // Deploy document contract
        document = Document(SafeSingletonDeployer.deploy({ creationCode: type(Document).creationCode, salt: salt }));

        // Deploy identifier implementation
        Identifier identifierImplementation =
            Identifier(SafeSingletonDeployer.deploy({ creationCode: type(Identifier).creationCode, salt: salt }));

        // Deploy Universal Resolver
        resolver = UniversalResolver(
            SafeSingletonDeployer.deploy({
                creationCode: type(UniversalResolver).creationCode,
                args: abi.encode(msg.sender, address(identifierImplementation), resolverUrl),
                salt: salt
            })
        );
        vm.stopBroadcast();
    }
}
