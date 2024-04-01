-include .env

deploy-anvil:
	forge script script/DeployLendingNft.s.sol --rpc-url $(RPC_URL_ANVIL) --private-key $(PRIVATE_KEY_ANVIL_DEPLOYER) --broadcast

deploy-blast:
	forge script script/DeployLendingNft.s.sol --rpc-url $(RPC_URL_BLAST) --private-key $(PRIVATE_KEY_BLAST) --broadcast --verify --etherscan-api-key $(BLASTSCAN_API_KEY) -vvvv

# testing
fork-test-blast:
	forge test --fork-url $(RPC_URL_BLAST)
