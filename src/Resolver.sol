// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

// Library Imports
import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { LibClone } from "solady/utils/LibClone.sol";

// Internal Imports
import { UniversalSigValidator } from "./utils/UniversalSigValidator.sol";
import { Document } from "./Document.sol";
import { Identifier } from "./Identifier.sol";

enum DIDStatus {
    Counterfactual,
    Signed,
    Fallback
}

struct DIDDocument {
    string data;
    bytes signature;
    DIDStatus status;
}

contract Resolver is Ownable, UniversalSigValidator, Document, EIP712 {

    /// @notice The implementation of the identity contract.
    address public immutable implementation;

    /// @notice The name of the resolver.
    string public constant NAME = "Universal Resolver";

    /// @notice The version of the resolver.
    string public constant DOMAIN_VERSION = "1";

    /// @notice The EIP-712 domain separator for the resolver.
    bytes32 public constant UNIVERSAL_DID_TYPEHASH = keccak256("UniversalDID(string document)");

    // TODO: We might want an array of URLs for redundancy?
    string public url;

    /// @notice Emitted when an offchain DID document lookup is initialized.
    /// @dev Follows EIP-3668 standard for offchain data requests.
    /// @param sender The address of the sender.
    /// @param urls The URLs to lookup.
    /// @param callData The call data to pass to the callback function.
    /// @param callbackFunction The callback function to call.
    /// @param extraData The extra data to pass to the callback function.
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);
    
    /// @notice Emitted when a new identifier is created.
    /// @param wallet The wallet address of the identifier.
    /// @param identity The address of the identifier contract.
    event IdentifierCreated(address indexed wallet, address indexed identity);

    /// @notice Emitted when the URL is updated.
    /// @param url The new URL.
    event URLUpdated(string url);

    constructor(address owner, address _implementation, string memory _url) EIP712(NAME, DOMAIN_VERSION) {
        _initializeOwner(owner);
        implementation = _implementation;
        url = _url;
    }

    /// @notice The domain separator for the resolver.
    function domainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @notice The init code hash for the identifier implementation.
    function initCodeHash() public view virtual returns (bytes32) {
        return LibClone.initCodeHashERC1967(implementation);
    }

    /// @notice The identifier address for a given account.
    /// @param account The account to get the identifier address for.
    /// @return identifier The identifier address.
    function getIdentifierAddress(address account) public view returns (address identifier) {
        return LibClone.predictDeterministicAddress(initCodeHash(), keccak256(abi.encodePacked(account)), address(this));
    }

    /// @notice The DID for a given account.
    /// @param account The account to get the DID for.
    /// @return did The decentralized identifier ID.
    function generateDID(address account) public view returns (string memory did) {
        return generateDID(address(this), account);
    }

    /// @notice Creates a new identifier contract for a given account.
    /// @param _account The account to create the identifier for.
    function create(address _account) external returns (address identifier) {
        (bool alreadyDeployed, address instance) =
            LibClone.createDeterministicERC1967(0, implementation, keccak256(abi.encodePacked(_account)));

        if (!alreadyDeployed) {
            Identifier(instance).initialize(address(this), _account);
        }

        emit IdentifierCreated(_account, instance);
        return instance;
    }

    /// @notice Looks up a DID document for a given wallet.
    /// @dev Step 1 of the DID resolution process.
    /// @param wallet The wallet to lookup the DID document for.
    function lookup(address wallet) external view returns (string memory) {
        address identifier_ = getIdentifierAddress(wallet);
        // If the identifier contract does not exist, an offchain DID document lookup request is initialized.
        // This is because users can update a DID document without deploying a new identity contract.
        if (identifier_.code.length == 0) {
            bytes memory callData = abi.encodePacked(wallet);
            bytes memory extraData = callData;
            string[] memory urls_ = new string[](1);
            urls_[0] = url;
            revert OffchainLookup(address(this), urls_, callData, this.resolve.selector, extraData);
        }
        // If the identifier contract exists, we trigger a lookup on the contract.
        // This is because the user may change the default URL of the DID document storage.
        Identifier(identifier_).lookup();
    }

    /// @notice Resolves a DID document for a given wallet.
    /// @dev Step 2 of the DID resolution process.
    /// @param response The response from the offchain DID document lookup.
    /// @param extraData The extra data to pass to the callback function.
    function resolve(
        bytes calldata response,
        bytes calldata extraData
    )
        external
        virtual
        returns (DIDDocument memory identifier)
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
            return DIDDocument({
                data: generateDocument(address(this), account),
                signature: signature,
                status: DIDStatus.Counterfactual
            });
        }

        bytes32 digest = _createDigest(document);
        try this.isValidSigImpl(account, digest, signature, true, false) returns (bool isValid) {
            if (!isValid) {
                return DIDDocument({
                    data: generateDocument(address(this), account),
                    signature: signature,
                    status: DIDStatus.Fallback
                });
            }
            return DIDDocument({
                data: document,
                signature: signature,
                status: DIDStatus.Signed
            });
        } catch (bytes memory) {
            return DIDDocument({
                data: generateDocument(address(this), account),
                signature: signature,
                status: DIDStatus.Fallback
            });
        }
    }

    /// @notice Updates the URL of the DID document.
    /// @param _url The new URL.
    function setUrl(string memory _url) onlyOwner external {
        emit URLUpdated(_url);
        url = _url;
    }

    function _createDigest(string memory document) internal view returns (bytes32 digest) {
        bytes32 documentHash = keccak256(abi.encode(UNIVERSAL_DID_TYPEHASH, keccak256(bytes(document))));
        digest = _hashTypedDataV4(documentHash);
    }
}
