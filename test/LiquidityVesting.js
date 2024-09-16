const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidityVesting", function () {
    let LiquidityVesting, ERC20Mock, vesting, erc20Mock, owner, teamWallet, other;



    beforeEach(async function () {
        [owner, teamWallet, other] = await ethers.getSigners();

        ERC20Mock = await ethers.getContractFactory("MockToken");
        erc20Mock = await ERC20Mock.deploy("MockToken", "MTK", ethers.parseEther('1000000'));
        await erc20Mock.waitForDeployment();

        LiquidityVesting = await ethers.getContractFactory("LiquidityVesting");
        vesting = await LiquidityVesting.deploy(erc20Mock.target, teamWallet.address, owner.address);
        await vesting.waitForDeployment();
        await erc20Mock.mint(teamWallet.address, ethers.parseEther("100000", 18));
        await erc20Mock.mint(owner.address, ethers.parseEther("100000", 18));

    });

    it("should start vesting period when called by owner", async function () {
        const startTimeBefore = await vesting.startTime();
        expect(startTimeBefore).to.equal(0);

        const txReceipt = await vesting.connect(owner).startVesting();
        const startTimeAfter = await vesting.startTime();

        expect(startTimeAfter).to.not.equal(0);

        await expect(txReceipt)
            .to.emit(vesting, 'VestingStarted')
            .withArgs(startTimeAfter);

        const vestingStartedEvents = await vesting.queryFilter('VestingStarted', txReceipt.blockNumber);
        const vestingStartedEvent = vestingStartedEvents[0];
        const emittedStartTime = vestingStartedEvent.args.startTime;
        expect(emittedStartTime).to.equal(startTimeAfter);
    });
    it("should revert if startVesting is called again", async function () {
        await vesting.connect(owner).startVesting();

        await expect(vesting.connect(owner).startVesting()).to.be.revertedWith("Vesting already started!");
    });
    it("should revert if startVesting is called by non-owner", async function () {
        try {
            vesting.connect(other).startVesting();
        } catch (error) {

            expect(error.message).to.include('Ownable: caller is not the owner');
            return;
        }

    });

    it("should set the token address", async function () {

        const tx = vesting.connect(owner).setTokenAddress("0x1234567890123456789012345678901234567890");
        await expect(tx)
            .to.emit(vesting, 'TokenAddressSetted')
            .withArgs("0x1234567890123456789012345678901234567890");

    });
    it("should change the team wallet address", async function () {

        const tx = vesting.connect(owner).setTeamWallet("0x1234567890123456789012345678901234567890");
        await expect(tx)
            .to.emit(vesting, 'TeamWalletChanged')
            .withArgs("0x1234567890123456789012345678901234567890");

    });

    it("should withdraw vested tokens to the team wallet", async function () {
        const requiredBalance = ethers.parseEther('1');
        const VESTING_DURATION = 29 * 60;
        const tx = await vesting.connect(owner).startVesting();
        await tx.wait();

        const startTimeBigInt = await vesting.startTime();
        const startTime = Number(startTimeBigInt);

        await teamWallet.sendTransaction({
            to: vesting.target,
            value: requiredBalance,
        });

        const cliffTime = startTime + VESTING_DURATION;

        const originalBlock = await ethers.provider.getBlock('latest');
        const originalTimestamp = originalBlock.timestamp;
        await network.provider.send("evm_setNextBlockTimestamp", [cliffTime]);
        const txWithdraw = await vesting.connect(owner).withdrawVestedTokens();
        await expect(txWithdraw)
            .to.emit(vesting, 'TokenClaimed')
            .withArgs(teamWallet.address, 0);

        await network.provider.send("evm_setNextBlockTimestamp", [originalTimestamp + 7779334]);
    });


    it("should withdraw vested tokens to the team wallet", async function () {
        const requiredBalance = ethers.parseEther('1');
        vesting.connect(owner).startVesting();

        await teamWallet.sendTransaction({
            to: vesting.target,
            value: requiredBalance.toString(),
        });

        const tx = vesting.connect(owner).withdrawVestedTokens();
        await expect(tx).to.be.revertedWith("Vesting under cliff!");

    });

    it("should return 0 if startTime is 0", async function () {
        const result = await vesting.vestedAmount();

        expect(result).to.equal(0);
    });
    it("should return token balance if currentTime is greater than startTime", async function () {
        const result = await vesting.vestedAmount();

        const tokenBalance = await erc20Mock.balanceOf(vesting.target);
        expect(result).to.equal(tokenBalance);
    });
});

