// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

// Internal Imports
import { Identifier } from "../src/Identifier.sol";
import { UniversalResolver, DIDDocument, DIDStatus } from "../src/UniversalResolver.sol";
import { CoreTest } from "./utils/CoreTest.t.sol";

contract EOATest is CoreTest {
    Identifier internal identifier;
    UniversalResolver internal resolver;

    function setUp() public virtual override {
        super.setUp();
        identifier = new Identifier();
        resolver = new UniversalResolver(users.alice.addr, address(identifier), "http://localhost:4200/{sender}");
    }

    function test_EOA_Counterfactual_Unsigned() external {
        string memory document =
            '{"@context": ["https://www.w3.org/ns/did/v1"],"id": "did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xbf0b5a4099f0bf6c8bc4252ebec548bae95602ea","verificationMethod": [{"id": "did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xbf0b5a4099f0bf6c8bc4252ebec548bae95602ea#controller-key","type": "EthEip6492","controller": "did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xbf0b5a4099f0bf6c8bc4252ebec548bae95602ea"}],"authentication": ["did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xbf0b5a4099f0bf6c8bc4252ebec548bae95602ea#controller-key"],"assertionMethod": ["did:uis:31337:0x2e234dae75c793f67a35089c9d99245e1c58470b:0xbf0b5a4099f0bf6c8bc4252ebec548bae95602ea#controller-key"]}';
        address instance = resolver.getIdentifierAddress(users.alice.addr);

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

            // Mock the URL response
            (uint256 resStatus, bytes memory resData) = mockGetDidUrlResponse(404, bytes("Base ID not found"), "empty");

            // Finish resolving the document i.e. verify the signature
            DIDDocument memory documentResolve = resolver.resolve(resData, extraData);
            assertEq(documentResolve.data, document, "Document should be resolved and verified");
        }
    }

    function test_EOA_Counterfactual_Signed() external {
        // NOTE: Simplified DID document for testing purposes.
        string memory _document = "{id: did:uis:chainId:resolver:identifier }";
        address instance = resolver.getIdentifierAddress(users.bob.addr);

        bytes32 documentHash = hashUniversalDID(resolver, _document);
        (bytes memory signature, bytes32 digest) =
            signEIP712Message(resolver.domainSeparator(), documentHash, users.bob.privateKey);

        // Resolve DID Document using the Resolver and Smart Wallet
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

            // Mock the URL response
            (uint256 resStatus, bytes memory resData) = mockGetDidUrlResponse(200, signature, _document);

            // Finish resolving the document i.e. verify the signature
            DIDDocument memory documentResolve = resolver.resolve(resData, extraData);
            assertEq(documentResolve.signature, signature, "Document signatures should match");
            assertEq(uint16(documentResolve.status), uint16(DIDStatus.Signed), "Document should be signed");
            assertEq(documentResolve.data, _document, "Document should be resolved and verified");
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

            // Mock the URL response
            (uint256 resStatus, bytes memory resData) = mockGetDidUrlResponse(404, bytes("Base ID not found"), "empty");

            // Finish resolving the document i.e. verify the signature
            DIDDocument memory documentResolved = resolver.resolve(resData, extraData);
            assertEq(documentResolved.data, document, "Document should be resolved and verified");
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

            // Mock the URL response
            (uint256 resStatus, bytes memory resData) = mockGetDidUrlResponse(404, bytes("Base ID not found"), "empty");

            // Finish resolving the document i.e. verify the signature
            DIDDocument memory documentResolved = resolver.resolve(resData, extraData);
            assertEq(documentResolved.data, document, "Document should be resolved and verified");
        }
    }

    function test_EOA_Materialized_Signed() external {
        // NOTE: Simplified DID document for testing purposes.
        string memory document = "{id: did:uis:chainId:resolver:identifier }";
        address instance = resolver.create(users.dave.addr);
        Identifier idInstance = Identifier(instance);

        bytes32 documentHash = hashUniversalDID(resolver, document);
        (bytes memory signature, bytes32 digest) =
            signEIP712Message(resolver.domainSeparator(), documentHash, users.dave.privateKey);

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

            // Mock the URL response
            (uint256 resStatus, bytes memory resData) = mockGetDidUrlResponse(200, signature, document);

            // Finish resolving the document i.e. verify the signature
            DIDDocument memory documentResolved = resolver.resolve(resData, extraData);
            assertEq(documentResolved.data, document, "Document should be resolved and verified");
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

            // Mock the URL response
            (uint256 resStatus, bytes memory resData) = mockGetDidUrlResponse(200, signature, document);

            // Finish resolving the document i.e. verify the signature
            DIDDocument memory documentResolved = resolver.resolve(resData, extraData);
            assertEq(documentResolved.data, document, "Document should be resolved and verified");
        }
    }
}
