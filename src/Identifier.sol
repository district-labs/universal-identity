// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

// Library Imports
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

// Internal Imports
import { Document } from "./Document.sol";
import { Resolver } from "./Resolver.sol";


contract Identifier is Document, UUPSUpgradeable {
    // TODO: We might want an array of URLs for redundancy.
    string public url;
    address public resolver;
    address public owner;

    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    event URLUpdated(string url);

    constructor() {}

    function initialize(address _resolver, address _owner) external {
        resolver = _resolver;
        owner = _owner;
    }

    function lookup() external view {
        bytes memory callData = abi.encodePacked(address(this));
        string[] memory urls_ = new string[](1);
        // If the URL is empty, we use the resolver's default  URL.
        urls_[0] = bytes(url).length == 0 ? Resolver(resolver).url() : url;
        revert OffchainLookup(address(this), urls_, callData, this.resolve.selector, abi.encodePacked(owner));
    }

    function resolve(
        bytes calldata response,
        bytes calldata extraData
    )
        external
        virtual
        returns (string memory document)
    {
        (uint16 status, bytes memory signature, string memory document) = abi.decode(response, (uint16, bytes, string));
        // If the DID document does not exist offchain, we generate a default DID document.
        if (status != uint16(200)) {
            return generate(resolver, owner);
        }

        // If the signature length is 65, we assumes it's from an EOA and we create a digest.
        // Otherwise, we assume it's a an ERC-6492 signature formatted for a smart wallet.
        // Smart Wallets should always sign with EIP-712 to prevent replay attacks.
        bytes32 digest = signature.length == 65 ? _createDigest(document) : keccak256(bytes(document));

        bool isValid =
            Resolver(resolver).isValidSigImpl(owner, digest, signature, true, false);
        if (!isValid) {
            return generate(resolver, owner);
        }

        return document;
    }

    function setUrl(string memory _url) external {
        require(msg.sender == owner, "Identity: Unauthorized");
        emit URLUpdated(_url);
        url = _url;
    }

    function _createDigest(string memory message) internal pure returns (bytes32) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n";
        bytes memory messageBytes = bytes(message);
        bytes memory messagePacked = abi.encodePacked(prefix, Strings.toString(messageBytes.length), message);
        return keccak256(messagePacked);
    }

    function _authorizeUpgrade(address) internal view virtual override(UUPSUpgradeable) { }
}
