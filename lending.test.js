const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("lending", function() {
    let owner
    let investor
    let user
    let contract

    beforeEach(async function(){
        [owner, investor, user] = await ethers.getSigners()

        const Lending = await ethers.getContractFactory("lending", owner)
        contract = await Lending.deploy()
        await contract.waitForDeployment()
        console.log("Owner address:", owner.getAddress())
    })

    if("sets owner", async function(){
        const currentOwner = await contract.owner
        console.log("Current Owner")
        expect(currentOwner).to.eq(owner.address)
    })
    
    async function getTimeStamp(bn){
        return(
            await ethers.provider.getBlock(bn)
        ).timestamp
    }

    async function investMoney(investor){
        const amount = 100
        const currentBlock = await ethers.provider.getBlock(await ethers.provider.getBlockNumber())
        const txData = {
            to: contract.getAddress(),
            value: amount,
            timestamp: currentBlock.timestamp
        }

        const tx = await investor.sendTransaction(txData);
        await tx.wait()
        return[tx, amount, timestamp]
    }

    describe("invest", function(){
        it("should allow to invest money", async function(){
            const[investMoneyTx, amount, timestampTx] = await investMoney(invesor)
            
            await expect (() => sendMoneyTx).to.changeEtherBalance(contract, amount)

            await expect (investMoney).to.emit(contract,"invested").withArgs(investor.getAddress(), amount, timestampTx)
        })
    })
    
    describe("withdraw", function(){
        it("should allow to withdraw money", async function(){
            const[_, amount] = await investMoney(investor)

            const tx = await contract.withdraw(investor)

            await expect (() => tx).to.changeEtherBalances([contract, investor],[-amount, amount])
        })
        
    })

})

