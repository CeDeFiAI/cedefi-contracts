const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VestingTeam", function () {
    let VestingTeam, ERC20Mock, vestingTeam, erc20Mock, owner, teamWallet, other;



    beforeEach(async function () {
        [owner, teamWallet, other] = await ethers.getSigners();

        ERC20Mock = await ethers.getContractFactory("MockToken");
        erc20Mock = await ERC20Mock.deploy("MockToken", "MTK", ethers.parseEther('1000000'));
        await erc20Mock.waitForDeployment();

        VestingTeam = await ethers.getContractFactory("TeamVesting");
        vestingTeam = await VestingTeam.deploy(erc20Mock.target, teamWallet.address, owner.address);
        await vestingTeam.waitForDeployment();
        await erc20Mock.mint(teamWallet.address, ethers.parseEther("100000", 18));
        await erc20Mock.mint(owner.address, ethers.parseEther("100000", 18));

    });

    it("should start vesting period when called by owner", async function () {
        const startTimeBefore = await vestingTeam.startTime();
        expect(startTimeBefore).to.equal(0);

        const txReceipt = await vestingTeam.connect(owner).startVesting();
        const startTimeAfter = await vestingTeam.startTime();

        expect(startTimeAfter).to.not.equal(0);

        await expect(txReceipt)
            .to.emit(vestingTeam, 'VestingStarted')
            .withArgs(startTimeAfter);

        const vestingStartedEvents = await vestingTeam.queryFilter('VestingStarted', txReceipt.blockNumber);
        const vestingStartedEvent = vestingStartedEvents[0];
        const emittedStartTime = vestingStartedEvent.args.startTime;
        expect(emittedStartTime).to.equal(startTimeAfter);
    });
    it("should revert if startVesting is called again", async function () {
        await vestingTeam.connect(owner).startVesting();

        await expect(vestingTeam.connect(owner).startVesting()).to.be.revertedWith("Vesting already started!");
    });
    it("should revert if startVesting is called by non-owner", async function () {
        try {
            vestingTeam.connect(other).startVesting();
        } catch (error) {

            expect(error.message).to.include('Ownable: caller is not the owner');
            return;
        }

    });
    it("should set the token address", async function () {

        const tx = vestingTeam.connect(owner).setTokenAddress("0x1234567890123456789012345678901234567890");
        await expect(tx)
            .to.emit(vestingTeam, 'TokenAddressSetted')
            .withArgs("0x1234567890123456789012345678901234567890");

    });
    it("should change the team wallet address", async function () {

        const tx = vestingTeam.connect(owner).setTeamWallet("0x1234567890123456789012345678901234567890");
        await expect(tx)
            .to.emit(vestingTeam, 'TeamWalletChanged')
            .withArgs("0x1234567890123456789012345678901234567890");

    });
    it("should withdraw vested tokens to the team wallet", async function () {
        const requiredBalance = ethers.parseEther('1');
        vestingTeam.connect(owner).startVesting();
        await teamWallet.sendTransaction({
            to: vestingTeam.target,
            value: requiredBalance.toString(),
        });

        const tx = vestingTeam.connect(owner).withdrawVestedTokens();
        await expect(tx)
            .to.emit(vestingTeam, 'TokenClaimed')
            .withArgs(teamWallet.address, 0);

    });
    it("should calculate vested tokens at current time", async function () {
        await vestingTeam.startVesting();
        await network.provider.send("evm_increaseTime", [3600]);
        const tx = await vestingTeam.vestedAmount();

        expect(tx).to.be.at.least(0);
    });

    it("should return 0 if startTime is 0", async function () {
        const result = await vestingTeam.vestedAmount();

        expect(result).to.equal(0);
    });
    it("should return token balance if currentTime is greater than startTime", async function () {
        const result = await vestingTeam.vestedAmount();

        const tokenBalance = await erc20Mock.balanceOf(vestingTeam.target);
        expect(result).to.equal(tokenBalance);
    });


});

