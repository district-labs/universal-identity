// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

// Testing Imports
import { console2 } from "forge-std/console2.sol";
import { Surl } from "surl/src/Surl.sol";
import { stdJson } from "forge-std/StdJson.sol";

// Lib Imports
import { CoinbaseSmartWalletFactory } from "smart-wallet/src/CoinbaseSmartWalletFactory.sol";
import { CoinbaseSmartWallet } from "smart-wallet/src/CoinbaseSmartWallet.sol";

// Internal Imports
import { Identifier } from "../src/Identifier.sol";
import { Resolver } from "../src/Resolver.sol";
import { CoreTest } from "./utils/CoreTest.t.sol";

contract SmartWalletTest is CoreTest {
    using Surl for *;
    using stdJson for string;

    bytes32 private constant ERC6492_DETECTION_SUFFIX =
        0x6492649264926492649264926492649264926492649264926492649264926492;

    CoinbaseSmartWallet internal smartWalletImpl;
    CoinbaseSmartWalletFactory internal factory;

    Identifier internal identifier;
    Resolver internal resolver;

    function setUp() public virtual override {
        super.setUp();
        smartWalletImpl = new CoinbaseSmartWallet();
        factory = new CoinbaseSmartWalletFactory(address(smartWalletImpl));

        identifier = new Identifier();
        resolver = new Resolver(users.alice.addr, address(identifier), "http://localhost:4200/{sender}");
    }

    function test_Counterfactual_Counterfactual_Unsigned() external {
        string memory document =
            '{"@context": ["https://www.w3.org/ns/did/v1"],"id": "did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0x2b8dad3f2091626459e37db6e7ef905e61147c1c","verificationMethod": [{"id": "did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0x2b8dad3f2091626459e37db6e7ef905e61147c1c#controller-key","type": "EthEip6492","controller": "did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0x2b8dad3f2091626459e37db6e7ef905e61147c1c"}],"authentication": ["did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0x2b8dad3f2091626459e37db6e7ef905e61147c1c#controller-key"],"assertionMethod": ["did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0x2b8dad3f2091626459e37db6e7ef905e61147c1c#controller-key"]}';
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(users.alice.addr);
        uint256 nonce = 0;
        address wallet = factory.getAddress(owners, nonce);
        address instance = resolver.getAddress(wallet);

        // // Resolve DID Document using the Resolver and Smart Wallet
        try resolver.lookup(address(wallet)) { }
        catch (bytes memory revertData) {
            uint256 offset = 4;
            uint256 len = revertData.length - offset;
            bytes memory data;
            assembly {
                data := add(revertData, offset)
                mstore(data, len)
            }
            (
                address sender,
                string[] memory urls,
                bytes memory callData,
                bytes4 callbackFunction,
                bytes memory extraData
            ) = abi.decode(data, (address, string[], bytes, bytes4, bytes));

            // Fetch the document from the URL
            string memory urlFormatted = buildURL(urls[0], instance);
            (uint256 resStatus, bytes memory resData) = urlFormatted.get();

            // Finish resolving the document i.e. verify the signature
            string memory documentResolve = resolver.resolve(_hexStringToBytes(string(resData)), extraData);
            assertEq(documentResolve, document, "Document should be resolved and verified");
        }
    }

    function test_Counterfactual_Counterfactual_Signed() external {
        // NOTE: Simplified DID document for testing purposes.
        string memory document = "{id: did:uis:chainId:resolver:identifier }";
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(users.alice.addr);
        uint256 nonce = 1;
        address wallet = factory.getAddress(owners, nonce);
        address instance = resolver.getAddress(wallet);

        // Sign the decentralized identifier document and send it to the server
        bytes32 _MESSAGE_TYPEHASH = keccak256("CoinbaseSmartWalletMessage(bytes32 hash)");
        bytes32 _MESSAGE = keccak256(abi.encode(_MESSAGE_TYPEHASH, keccak256(bytes(document))));
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Coinbase Smart Wallet")),
                keccak256(bytes("1")),
                block.chainid,
                wallet
            )
        );
        (bytes memory signature, bytes32 digestEIP712) =
            signEIP712Message(domainSeparator, _MESSAGE, users.alice.privateKey);

        // Correctly format the signature to support Coinbase Smart Wallet and ERC-6492
        bytes memory cbswEncodedSignature = abi.encode(uint256(0), signature);
        bytes memory magicSignature = bytes.concat(
            abi.encode(
                address(factory),
                abi.encodeWithSelector(factory.createAccount.selector, owners, nonce),
                cbswEncodedSignature
            ),
            ERC6492_DETECTION_SUFFIX
        );

        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        string memory message = _constructMsg(vm.toString(instance), document, vm.toString(magicSignature));
        "http://localhost:4200/write".post(headers, message);

        // // Resolve DID Document using the Resolver and Smart Wallet
        try resolver.lookup(address(wallet)) { }
        catch (bytes memory revertData) {
            uint256 offset = 4;
            uint256 len = revertData.length - offset;
            bytes memory data;
            assembly {
                data := add(revertData, offset)
                mstore(data, len)
            }
            (
                address sender,
                string[] memory urls,
                bytes memory callData,
                bytes4 callbackFunction,
                bytes memory extraData
            ) = abi.decode(data, (address, string[], bytes, bytes4, bytes));

            // Fetch the document from the URL
            string memory urlFormatted = buildURL(urls[0], instance);
            (uint256 resStatus, bytes memory resData) = urlFormatted.get();

            // Finish resolving the document i.e. verify the signature
            string memory documentResolve = resolver.resolve(_hexStringToBytes(string(resData)), extraData);
            assertEq(documentResolve, document, "Document should be resolved and verified");
        }
    }

    function test_Materialized_Counterfactual_Signed() external {
        // NOTE: Simplified DID document for testing purposes.
        string memory document = "{id: did:uis:chainId:resolver:identifier }";
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(users.alice.addr);
        uint256 nonce = 3;
        address wallet = address(factory.createAccount(owners, nonce));
        address instance = resolver.getAddress(wallet);

        // Sign the decentralized identifier document and send it to the server
        bytes32 _MESSAGE_TYPEHASH = keccak256("CoinbaseSmartWalletMessage(bytes32 hash)");
        bytes32 _MESSAGE = keccak256(abi.encode(_MESSAGE_TYPEHASH, keccak256(bytes(document))));
        bytes32 domainSeparator = CoinbaseSmartWallet(payable(wallet)).domainSeparator();
        (bytes memory signature, bytes32 digestEIP712) =
            signEIP712Message(domainSeparator, _MESSAGE, users.alice.privateKey);

        // Correctly format the signature to support Coinbase Smart Wallet and ERC-6492
        bytes memory cbswEncodedSignature = abi.encode(uint256(0), signature);
        bytes memory magicSignature = bytes.concat(
            abi.encode(
                address(factory),
                abi.encodeWithSelector(factory.createAccount.selector, owners, nonce),
                cbswEncodedSignature
            ),
            ERC6492_DETECTION_SUFFIX
        );

        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        string memory message = _constructMsg(vm.toString(instance), document, vm.toString(magicSignature));
        "http://localhost:4200/write".post(headers, message);

        // // Resolve DID Document using the Resolver and Smart Wallet
        try resolver.lookup(address(wallet)) { }
        catch (bytes memory revertData) {
            uint256 offset = 4;
            uint256 len = revertData.length - offset;
            bytes memory data;
            assembly {
                data := add(revertData, offset)
                mstore(data, len)
            }
            (
                address sender,
                string[] memory urls,
                bytes memory callData,
                bytes4 callbackFunction,
                bytes memory extraData
            ) = abi.decode(data, (address, string[], bytes, bytes4, bytes));

            // Fetch the document from the URL
            string memory urlFormatted = buildURL(urls[0], instance);
            (uint256 resStatus, bytes memory resData) = urlFormatted.get();

            // Finish resolving the document i.e. verify the signature
            string memory documentResolve = resolver.resolve(_hexStringToBytes(string(resData)), extraData);
            assertEq(documentResolve, document, "Document should be resolved and verified");
        }
    }

    function test_Materialized_Counterfactual_Unsigned() external {
        string memory document =
            '{"@context": ["https://www.w3.org/ns/did/v1"],"id": "did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0x0e59e2628ea74fff73b21042eaeb393c100a4704","verificationMethod": [{"id": "did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0x0e59e2628ea74fff73b21042eaeb393c100a4704#controller-key","type": "EthEip6492","controller": "did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0x0e59e2628ea74fff73b21042eaeb393c100a4704"}],"authentication": ["did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0x0e59e2628ea74fff73b21042eaeb393c100a4704#controller-key"],"assertionMethod": ["did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0x0e59e2628ea74fff73b21042eaeb393c100a4704#controller-key"]}';
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(users.alice.addr);
        uint256 nonce = 4;
        address wallet = address(factory.createAccount(owners, nonce));
        address instance = resolver.getAddress(wallet);

        // // Resolve DID Document using the Resolver and Smart Wallet
        try resolver.lookup(address(wallet)) { }
        catch (bytes memory revertData) {
            uint256 offset = 4;
            uint256 len = revertData.length - offset;
            bytes memory data;
            assembly {
                data := add(revertData, offset)
                mstore(data, len)
            }
            (
                address sender,
                string[] memory urls,
                bytes memory callData,
                bytes4 callbackFunction,
                bytes memory extraData
            ) = abi.decode(data, (address, string[], bytes, bytes4, bytes));

            // Fetch the document from the URL
            string memory urlFormatted = buildURL(urls[0], instance);
            (uint256 resStatus, bytes memory resData) = urlFormatted.get();

            // Finish resolving the document i.e. verify the signature
            string memory documentResolve = resolver.resolve(_hexStringToBytes(string(resData)), extraData);
            assertEq(documentResolve, document, "Document should be resolved and verified");
        }
    }

    function test_Materialized_Materialized_Unsigned() external {
        string memory document =
            '{"@context": ["https://www.w3.org/ns/did/v1"],"id": "did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0xfd6e4cfb40dba065a1c6217be6e4e3fe829ca0d4","verificationMethod": [{"id": "did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0xfd6e4cfb40dba065a1c6217be6e4e3fe829ca0d4#controller-key","type": "EthEip6492","controller": "did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0xfd6e4cfb40dba065a1c6217be6e4e3fe829ca0d4"}],"authentication": ["did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0xfd6e4cfb40dba065a1c6217be6e4e3fe829ca0d4#controller-key"],"assertionMethod": ["did:uis:31337:0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9:0xfd6e4cfb40dba065a1c6217be6e4e3fe829ca0d4#controller-key"]}';
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(users.alice.addr);
        uint256 nonce = 6;
        address wallet = address(factory.createAccount(owners, nonce));
        address instance = resolver.create(wallet);
        Identifier idInstance = Identifier(instance);

        // Test Resolution ------------------------------------------------ //
        // Resolve DID Document using the Identifier Contract
        try idInstance.lookup() { }
        catch (bytes memory revertData) {
            uint256 offset = 4;
            uint256 len = revertData.length - offset;
            bytes memory data;
            assembly {
                data := add(revertData, offset)
                mstore(data, len)
            }
            (
                address sender,
                string[] memory urls,
                bytes memory callData,
                bytes4 callbackFunction,
                bytes memory extraData
            ) = abi.decode(data, (address, string[], bytes, bytes4, bytes));

            // Fetch the document from the URL
            string memory urlFormatted = buildURL(urls[0], instance);
            (uint256 resStatus, bytes memory resData) = urlFormatted.get();

            // Finish resolving the document i.e. verify the signature
            string memory documentResolved = idInstance.resolve(_hexStringToBytes(string(resData)), extraData);
            assertEq(documentResolved, document, "Document should be resolved and verified");
        }

        // // Resolve DID Document using the Resolver and Smart Wallet
        try resolver.lookup(address(wallet)) { }
        catch (bytes memory revertData) {
            uint256 offset = 4;
            uint256 len = revertData.length - offset;
            bytes memory data;
            assembly {
                data := add(revertData, offset)
                mstore(data, len)
            }
            (
                address sender,
                string[] memory urls,
                bytes memory callData,
                bytes4 callbackFunction,
                bytes memory extraData
            ) = abi.decode(data, (address, string[], bytes, bytes4, bytes));

            // Fetch the document from the URL
            string memory urlFormatted = buildURL(urls[0], instance);
            (uint256 resStatus, bytes memory resData) = urlFormatted.get();

            // Finish resolving the document i.e. verify the signature
            string memory documentResolve = resolver.resolve(_hexStringToBytes(string(resData)), extraData);
            assertEq(documentResolve, document, "Document should be resolved and verified");
        }
    }

    function test_Materialized_Materialized_Signed() external {
        // NOTE: Simplified DID document for testing purposes.
        string memory document = "{id: did:uis:chainId:resolver:identifier }";
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(users.alice.addr);
        uint256 nonce = 7;
        address wallet = address(factory.createAccount(owners, nonce));
        address instance = resolver.create(wallet);
        Identifier idInstance = Identifier(instance);

        // Sign the decentralized identifier document and send it to the server
        bytes32 _MESSAGE_TYPEHASH = keccak256("CoinbaseSmartWalletMessage(bytes32 hash)");
        bytes32 _MESSAGE = keccak256(abi.encode(_MESSAGE_TYPEHASH, keccak256(bytes(document))));
        bytes32 domainSeparator = CoinbaseSmartWallet(payable(wallet)).domainSeparator();
        (bytes memory signature, bytes32 digestEIP712) =
            signEIP712Message(domainSeparator, _MESSAGE, users.alice.privateKey);

        // Correctly format the signature to support Coinbase Smart Wallet and ERC-6492
        bytes memory cbswEncodedSignature = abi.encode(uint256(0), signature);
        bytes memory magicSignature = bytes.concat(
            abi.encode(
                address(factory),
                abi.encodeWithSelector(factory.createAccount.selector, owners, nonce),
                cbswEncodedSignature
            ),
            ERC6492_DETECTION_SUFFIX
        );

        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        string memory message = _constructMsg(vm.toString(instance), document, vm.toString(magicSignature));
        "http://localhost:4200/write".post(headers, message);

        // Test Resolution ------------------------------------------------ //
        // Resolve DID Document using the Identifier Contract
        try idInstance.lookup() { }
        catch (bytes memory revertData) {
            uint256 offset = 4;
            uint256 len = revertData.length - offset;
            bytes memory data;
            assembly {
                data := add(revertData, offset)
                mstore(data, len)
            }
            (
                address sender,
                string[] memory urls,
                bytes memory callData,
                bytes4 callbackFunction,
                bytes memory extraData
            ) = abi.decode(data, (address, string[], bytes, bytes4, bytes));

            // Fetch the document from the URL
            string memory urlFormatted = buildURL(urls[0], instance);
            (uint256 resStatus, bytes memory resData) = urlFormatted.get();

            // Finish resolving the document i.e. verify the signature
            string memory documentResolved = idInstance.resolve(_hexStringToBytes(string(resData)), extraData);
            assertEq(documentResolved, document, "Document should be resolved and verified");
        }

        // // Resolve DID Document using the Resolver and Smart Wallet
        try resolver.lookup(address(wallet)) { }
        catch (bytes memory revertData) {
            uint256 offset = 4;
            uint256 len = revertData.length - offset;
            bytes memory data;
            assembly {
                data := add(revertData, offset)
                mstore(data, len)
            }
            (
                address sender,
                string[] memory urls,
                bytes memory callData,
                bytes4 callbackFunction,
                bytes memory extraData
            ) = abi.decode(data, (address, string[], bytes, bytes4, bytes));

            // Fetch the document from the URL
            string memory urlFormatted = buildURL(urls[0], instance);
            (uint256 resStatus, bytes memory resData) = urlFormatted.get();

            // Finish resolving the document i.e. verify the signature
            string memory documentResolve = resolver.resolve(_hexStringToBytes(string(resData)), extraData);
            assertEq(documentResolve, document, "Document should be resolved and verified");
        }
    }

    function _constructMsg(
        string memory account,
        string memory document,
        string memory signature
    )
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            "{", '"address": "', account, '",', '"document": "', document, '",', '"signature": "', signature, '"}'
        );
    }
}
