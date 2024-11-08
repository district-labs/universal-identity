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

    constructor() { }

    function initialize(address _resolver, address _owner) external {
        resolver = _resolver;
        owner = _owner;
    }

    function lookup() external view {
        bytes memory callData = abi.encodePacked(owner);
        bytes memory extraData = callData;
        string[] memory urls_ = new string[](1);
        // If the URL is empty, we use the resolver's default  URL.
        urls_[0] = bytes(url).length == 0 ? Resolver(resolver).url() : url;
        revert OffchainLookup(resolver, urls_, callData, Resolver.resolve.selector, extraData);
    }

    function setUrl(string memory _url) external {
        require(msg.sender == owner, "Identity: Unauthorized");
        emit URLUpdated(_url);
        url = _url;
    }

    function _authorizeUpgrade(address) internal view virtual override(UUPSUpgradeable) { }
}
