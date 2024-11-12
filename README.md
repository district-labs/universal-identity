# Universal Identity

The Universal Identity System is a scalable DID standard for the Ethereum ecosystem: 

- Free Setup: no gas fees to create or update
- Scalable Design: minimal onchain data storage
- Verifiable Signatures: EIP-3668 for offchain data lookups

The UIS DID standard supports all EVM account types: EOA, Contract, and Smart Wallets.

### Background on DID Standards

Decentralized Identifiers (DIDs) are a new type of identifier that enables verifiable, decentralized digital identity. Existing DID methods like `did:web`, `did:pkh`, and `did:ethr` have paved the way for decentralized identity but come with their own set of challenges:

- **`did:web`**: Relies heavily on centralized web infrastructure, which can lead to centralization risks and dependencies on domain name systems.
- **`did:pkh`**: Lacks flexibility in adding new verification methods, limiting accessibility and scalability.
- **`did:ethr`**: While more decentralized, it can be costly and less scalable due to onchain operations for every identity update.

These limitations hinder widespread adoption and scalability, prompting the need for a more balanced solution.

## The UIS Solution

UIS addresses these challenges by striking a balance between onchain and offchain.

It maintains the core principles of self-sovereign identity while achieving scalability through trusted centralized services. By combining elements of `did:web`, `did:pkh`, and `did:ethr`, UIS forms a modern DID standard capable of scaling to millions of users.

## Usage

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Format

Format the contracts:

```sh
$ forge fmt
```

## Contributors

- [Carl Fairclough](https://x.com/carlfairclough) | [Oscillator, Inc](https://osc.wtf)
- [Vitor Marthendal](https://x.com/VitorMarthendal) | [District Labs, Inc](https://www.districtlabs.com/)
- [Kames Geraghty](https://x.com/KamesGeraghty) | [District Labs, Inc](https://www.districtlabs.com/)

## License

This project is licensed under MIT.
