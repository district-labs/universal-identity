// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

// Library Imports
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { LibClone } from "solady/utils/LibClone.sol";

// Internal Imports
import { UniversalSigValidator } from "./utils/UniversalSigValidator.sol";
import { Document } from "./Document.sol";
import { Identifier } from "./Identifier.sol";

contract Resolver is Ownable, UniversalSigValidator, Document {
    // TODO: We might want an array of URLs for redundancy.
    string public url;
    address public immutable implementation;

    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    event IdentifierCreated(address indexed wallet, address indexed identity);

    constructor(address owner, address _implementation, string memory _url) {
        _initializeOwner(owner);
        implementation = _implementation;
        url = _url;
    }

    function create(address _account) external returns (address) {
        (bool alreadyDeployed, address instance) =
            LibClone.createDeterministicERC1967(0, implementation, keccak256(abi.encodePacked(_account)));

        if (!alreadyDeployed) {
            Identifier(instance).initialize(address(this), _account);
        }

        emit IdentifierCreated(_account, instance);
        return instance;
    }

    function lookup(address wallet) external view returns (string memory) {
        address identifier_ = getAddress(wallet);
        // If the identifier contract does not exist, an offchain DID document lookup request is initialized.
        // This is because users can update a DID document without deploying a new identity contract.
        if (identifier_.code.length == 0) {
            bytes memory callData = abi.encodePacked(address(this));
            string[] memory urls_ = new string[](1);
            urls_[0] = url;
            revert OffchainLookup(address(this), urls_, callData, this.resolve.selector, abi.encodePacked(wallet));
        }
        // If the identifier contract exists, we trigger a lookup on the contract.
        // This is because the user may change the default URL of the DID document storage.
        Identifier(identifier_).lookup();
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

        address account;
        assembly {
            // The offset of extraData in calldata
            let offset := extraData.offset
            // Load the first 32 bytes starting from offset
            let data := calldataload(offset)
            // Shift right by 12 bytes (96 bits) to get the address
            account := shr(96, data)
        }

        // If the DID document does not exist offchain, we generate a default DID document.
        // This could happen if the user has not set up a DID document or a server is not responding.
        // In either case, we want a default DID document to always be returned.
        if (status != uint16(200)) {
            return generate(address(this), account);
        }

        // If the signature length is 65, we assumes it's from an EOA and we create a digest.
        // Otherwise, we assume it's a an ERC-6492 signature formatted for a smart wallet.
        // Smart Wallets should always sign with EIP-712 to prevent replay attacks.
        bytes32 digest = signature.length == 65 ? _createDigest(document) : keccak256(bytes(document));

        bool isValid = this.isValidSigImpl(account, digest, signature, true, false);
        try this.isValidSigImpl(account, digest, signature, true, false) returns (bool isValid) {
            if (!isValid) {
                return generate(address(this), account);
            }
            return document;
        } catch (bytes memory error) {
            return generate(address(this), account);
        }

    }

    function getAddress(address account) public view returns (address) {
        return LibClone.predictDeterministicAddress(initCodeHash(), keccak256(abi.encodePacked(account)), address(this));
    }

    function initCodeHash() public view virtual returns (bytes32) {
        return LibClone.initCodeHashERC1967(implementation);
    }

    function _createDigest(string memory message) internal pure returns (bytes32) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n";
        bytes memory messageBytes = bytes(message);
        bytes memory messagePacked = abi.encodePacked(prefix, Strings.toString(messageBytes.length), message);
        return keccak256(messagePacked);
    }
}
