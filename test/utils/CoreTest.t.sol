// SPDX-License-Identifier: MIT AND Apache-2.0
pragma solidity >=0.8.23;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

struct TestUser {
    string name;
    address payable addr;
    uint256 privateKey;
}

struct TestUsers {
    TestUser alice;
    TestUser bob;
    TestUser carol;
    TestUser dave;
    TestUser eve;
    TestUser frank;
}

abstract contract CoreTest is Test {
    TestUsers internal users;
    ////////////////////////////// Set Up //////////////////////////////

    function setUp() public virtual {
        // Create users
        users = _createUsers();
    }

    // Name is the seed used to generate the address, private key, and DeleGator.
    function createUser(string memory _name) public returns (TestUser memory user_) {
        (address addr_, uint256 privateKey_) = makeAddrAndKey(_name);
        vm.deal(addr_, 100 ether);
        vm.label(addr_, _name);

        user_.name = _name;
        user_.addr = payable(addr_);
        user_.privateKey = privateKey_;
    }

    function signMessage(string memory message, uint256 privateKey) public pure returns (bytes memory) {
        // Correct message prefixing
        bytes memory prefix = "\x19Ethereum Signed Message:\n";
        bytes memory messageBytes = bytes(message);
        bytes memory messagePacked = abi.encodePacked(prefix, Strings.toString(messageBytes.length), message);
        bytes32 messageHash = keccak256(messagePacked);

        // Sign the message hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);

        // The signature
        return abi.encodePacked(r, s, v);
    }

    function signEIP712Message(
        bytes32 domainSeparator,
        bytes32 messageHash,
        uint256 privateKey
    )
        public
        pure
        returns (bytes memory, bytes32)
    {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return (abi.encodePacked(r, s, v), digest);

        // address signer = ecrecover(digest, v, r, s);
        // assertEq(signer, expectedSigner, "Invalid signer");
    }

    function buildURL(string memory baseURL, address sender) public pure returns (string memory) {
        string memory senderAddress = _toAsciiString(sender);
        string memory placeholder = "{sender}";

        bytes memory baseURLBytes = bytes(baseURL);
        bytes memory placeholderBytes = bytes(placeholder);
        bytes memory senderAddressBytes = bytes(senderAddress);

        // Find the index of the placeholder in the base URL
        int256 index = _indexOf(baseURLBytes, placeholderBytes);
        require(index >= 0, "Placeholder not found");

        // Calculate the length of the new URL
        uint256 newLength = baseURLBytes.length - placeholderBytes.length + senderAddressBytes.length;
        bytes memory result = new bytes(newLength);

        uint256 k = 0;
        // Copy characters before the placeholder
        for (uint256 i = 0; i < uint256(index); i++) {
            result[k++] = baseURLBytes[i];
        }

        // Insert the sender's address
        for (uint256 i = 0; i < senderAddressBytes.length; i++) {
            result[k++] = senderAddressBytes[i];
        }

        // Copy characters after the placeholder
        for (uint256 i = uint256(index) + placeholderBytes.length; i < baseURLBytes.length; i++) {
            result[k++] = baseURLBytes[i];
        }

        return string(result);
    }

    // Helper function to find the index of a substring
    function _indexOf(bytes memory haystack, bytes memory needle) internal pure returns (int256) {
        if (needle.length == 0 || haystack.length < needle.length) {
            return -1;
        }
        for (uint256 i = 0; i <= haystack.length - needle.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) {
                return int256(i);
            }
        }
        return -1;
    }

    // Converts an address to its ASCII string representation
    function _toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(42); // '0x' plus 40 hex characters
        s[0] = "0";
        s[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) % 16);
            s[2 * i + 2] = char(hi);
            s[2 * i + 3] = char(lo);
        }
        return string(s);
    }

    // Converts a byte to its ASCII character
    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 48); // '0' to '9'

        else return bytes1(uint8(b) + 87); // 'a' to 'f'
    }

    function _hexStringToBytes(string memory hexString) public pure returns (bytes memory) {
        bytes memory strBytes = bytes(hexString);
        uint256 hexLength = strBytes.length;

        // Create a new bytes array to hold the filtered hex characters
        bytes memory filtered = new bytes(hexLength);
        uint256 filteredLength = 0;

        uint256 i = 0;
        while (i < hexLength) {
            // Check for '0x' or '0X' and skip them
            if (strBytes[i] == "0" && i + 1 < hexLength && (strBytes[i + 1] == "x" || strBytes[i + 1] == "X")) {
                i += 2; // Skip the '0x'
                continue;
            }
            filtered[filteredLength] = strBytes[i];
            filteredLength++;
            i++;
        }

        require(filteredLength % 2 == 0, "Hex string must have an even length after filtering");

        bytes memory result = new bytes(filteredLength / 2);
        for (i = 0; i < filteredLength / 2; i++) {
            result[i] = bytes1(_fromHexChar(uint8(filtered[2 * i])) * 16 + _fromHexChar(uint8(filtered[2 * i + 1])));
        }

        return result;
    }

    function _fromHexChar(uint8 c) internal pure returns (uint8) {
        if (c >= uint8(bytes1("0")) && c <= uint8(bytes1("9"))) {
            return c - uint8(bytes1("0"));
        }
        if (c >= uint8(bytes1("a")) && c <= uint8(bytes1("f"))) {
            return 10 + c - uint8(bytes1("a"));
        }
        if (c >= uint8(bytes1("A")) && c <= uint8(bytes1("F"))) {
            return 10 + c - uint8(bytes1("A"));
        }
        revert("Invalid hex character");
    }

    ////////////////////////////// Private //////////////////////////////

    function _createUsers() private returns (TestUsers memory users_) {
        users_.alice = createUser("Alice");
        users_.bob = createUser("Bob");
        users_.carol = createUser("Carol");
        users_.dave = createUser("Dave");
        users_.eve = createUser("Eve");
        users_.frank = createUser("Frank");
    }
}
