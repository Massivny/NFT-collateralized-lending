# NFT-collateralized-lending
dApp that provide users with the ability to borrow stablecoins using NFT as collateral


## Working with contract

1. Clone git repo and build project

```bash
git clone git@github.com:Massivny/NFT-collateralized-lending
cd NFT-collateralized-lending
forge build
```

2. To deploy and testing with the contract, create your `.env` file; an example is provided in the repository. Than utilize a Makefile.

```bash
# to deploy to a specific network
make deploy-anvil
make deploy-blast

#tests on anvil local network
forge test
```

To run tests on blast fork you can have an NFT with `id == 2` and address of this NFT contract. Set this information in `.env` file. Than run command:

```bash
fork-test-blast
```