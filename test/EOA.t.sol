// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

// Testing Imports
import { console2 } from "forge-std/console2.sol";
import { Surl } from "surl/src/Surl.sol";
import { stdJson } from "forge-std/StdJson.sol";

// Internal Imports
import { Identifier } from "../src/Identifier.sol";
import { Resolver } from "../src/Resolver.sol";
import { CoreTest } from "./utils/CoreTest.t.sol";

contract EOATest is CoreTest {
    using Surl for *;
    using stdJson for string;

    Identifier internal identifier;
    Resolver internal resolver;

    function setUp() public virtual override {
        super.setUp();
        identifier = new Identifier();
        resolver = new Resolver(users.alice.addr, address(identifier), "http://localhost:4200/{sender}");
    }

    function test_EOA_Counterfactual_Unsigned() external {
        string memory document =
            '{"@context": ["https://www.w3.org/ns/did/v1"],"id": "did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xbf0b5a4099f0bf6c8bc4252ebec548bae95602ea","verificationMethod": [{"id": "did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xbf0b5a4099f0bf6c8bc4252ebec548bae95602ea#controller-key","type": "EthEip6492","controller": "did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xbf0b5a4099f0bf6c8bc4252ebec548bae95602ea"}],"authentication": ["did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xbf0b5a4099f0bf6c8bc4252ebec548bae95602ea#controller-key"],"assertionMethod": ["did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xbf0b5a4099f0bf6c8bc4252ebec548bae95602ea#controller-key"]}';
        address instance = resolver.getAddress(users.alice.addr);

        // // Resolve DID Document using the Resolver and Smart Wallet
        try resolver.lookup(users.alice.addr) { }
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

    function test_EOA_Counterfactual_Signed() external {
        // NOTE: Simplified DID document for testing purposes.
        string memory document = "{id: did:uis:chainId:resolver:identifier }";
        address instance = resolver.getAddress(users.bob.addr);

        bytes memory signature = signMessage(document, users.bob.privateKey);

        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        string memory message = _constructMsg(vm.toString(instance), document, vm.toString(signature));
        "http://localhost:4200/write".post(headers, message);

        // // Resolve DID Document using the Resolver and Smart Wallet
        try resolver.lookup(users.bob.addr) { }
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

    function test_EOA_Materialized_Unsigned() external {
        string memory document =
            '{"@context": ["https://www.w3.org/ns/did/v1"],"id": "did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xddf4497d39b10cf50af640942cc15233970da0c2","verificationMethod": [{"id": "did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xddf4497d39b10cf50af640942cc15233970da0c2#controller-key","type": "EthEip6492","controller": "did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xddf4497d39b10cf50af640942cc15233970da0c2"}],"authentication": ["did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xddf4497d39b10cf50af640942cc15233970da0c2#controller-key"],"assertionMethod": ["did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xddf4497d39b10cf50af640942cc15233970da0c2#controller-key"]}';
        address instance = resolver.create(users.carol.addr);
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
        try resolver.lookup(users.carol.addr) { }
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

    function test_EOA_Materialized_Signed() external {
        // NOTE: Simplified DID document for testing purposes.
        string memory document = "{id: did:uis:chainId:resolver:identifier }";
        address instance = resolver.create(users.dave.addr);
        Identifier idInstance = Identifier(instance);

         bytes memory signature = signMessage(document, users.dave.privateKey);

        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        string memory message = _constructMsg(vm.toString(instance), document, vm.toString(signature));
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
        try resolver.lookup(users.dave.addr) { }
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
