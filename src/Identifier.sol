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
    /// @notice The address of the public resolver.
    address public resolver;
    
    /// @notice The address of the account that owns the identifier.
    address public owner;
    
    // TODO: We might want an array of URLs for redundancy.
    string public url;

    /// @notice Emitted when an offchain DID document lookup is initialized.
    /// @dev Follows EIP-3668 standard for offchain data requests.
    /// @param sender The address of the sender.
    /// @param urls The URLs to lookup.
    /// @param callData The call data to pass to the callback function.
    /// @param callbackFunction The callback function to call.
    /// @param extraData The extra data to pass to the callback function.
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    /// @notice Reverts if the caller is not the owner.
    error InvalidOwner();

    /// @notice Emitted when the URL is updated.
    /// @param url The new URL.
    event URLUpdated(string url);

    constructor() { }

    /// @notice Initializes the identifier with the resolver and owner.
    /// @param _resolver The address of the public resolver.
    /// @param _owner The address of the account that owns the identifier.
    function initialize(address _resolver, address _owner) external {
        resolver = _resolver;
        owner = _owner;
    }

    /// @notice Looks up a DID document for a given wallet.
    /// @dev Step 1 of the DID resolution process.
    function lookup() external view returns (string memory) {
        bytes memory callData = abi.encodePacked(owner);
        bytes memory extraData = callData;
        string[] memory urls_ = new string[](1);
        // If the URL is empty, we use the resolver's default  URL.
        urls_[0] = bytes(url).length == 0 ? Resolver(resolver).url() : url;
        revert OffchainLookup(resolver, urls_, callData, Resolver.resolve.selector, extraData);
    }

    /// @notice Updates the URL of the DID document.
    /// @param _url The new URL.
    function setUrl(string memory _url) external {
        if (msg.sender != owner) {
            revert InvalidOwner();
        }
        emit URLUpdated(_url);
        url = _url;
    }

    function _authorizeUpgrade(address) internal view virtual override(UUPSUpgradeable) { }
}
