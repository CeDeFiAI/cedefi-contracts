const { expect } = require('chai');
const { ethers } = require('hardhat');
describe('CDFiSubscription', function () {
    let cdfiSubscription;
    let mockUSDT;
    let mockUSDC;
    let mockCDFi;
    let chainId;
    let priceFeedAddress;
    let addr1;
    let addr2;
    let addr3;
    let deployer;
    let mockPool;
    let mockChainlinkAggregator;
    beforeEach(async function () {
        [deployer, addr1, addr2, addr3] = await ethers.getSigners();
        const latestRoundId = 1; // Primjer: ID najnovijeg kola (round)
        const latestAnswer = ethers.parseUnits('3000', 8); // Primjer: Cijena u osam decimala
        const latestTimestamp = Math.floor(Date.now() / 1000);
        const MockToken = await ethers.getContractFactory('MockToken');
        mockUSDT = await MockToken.deploy("USDT", "USDT", ethers.parseEther('1000000'));
        mockUSDC = await MockToken.deploy("USDC", "USDC", ethers.parseEther('1000000'));
        mockCDFi = await MockToken.deploy("CDFi", "CFi", ethers.parseEther('1000000'));

        const CDFiSubscription = await ethers.getContractFactory('CDFiSubscription');

        cdfiSubscription = await CDFiSubscription.deploy(
            mockUSDT.target,
            mockUSDC.target,
            mockCDFi.target,
            deployer.address,
            'CDFiSubscription',
            'CDS'
        );
        cdfiSubscription.waitForDeployment();

        chainId = await ethers.provider.getNetwork().then((network) => network.chainId);
        const MockUniswapV3Pool = await ethers.getContractFactory('MockUniswapV3Pool');

        mockPool = await MockUniswapV3Pool.deploy(mockUSDT.target, mockCDFi.target);

        const MockChainlinkAggregator = await ethers.getContractFactory('MockChainlinkAggregator');

        mockChainlinkAggregator = await MockChainlinkAggregator.deploy(latestRoundId, latestAnswer, latestTimestamp);

        priceFeedAddress = '0x1234567890123456789012345678901234567890'; //dummy address
    });

    it('should update Chainlink price feed address by owner', async function () {

        await cdfiSubscription.connect(deployer).updateChainlinkPriceFeed(chainId, priceFeedAddress);

        const updatedPriceFeedAddress = await cdfiSubscription.priceFeedAddresses(chainId);
        expect(updatedPriceFeedAddress).to.equal(priceFeedAddress);
        await expect(cdfiSubscription.connect(deployer).updateChainlinkPriceFeed(chainId, priceFeedAddress))
            .to.emit(cdfiSubscription, 'PriceFeedChanged')
            .withArgs(chainId, priceFeedAddress);

    });
    it('should revert if non-owner tries to update Chainlink price feed address', async function () {
        try {
            await cdfiSubscription.connect(addr1).updateChainlinkPriceFeed(chainId, priceFeedAddress);
        } catch (error) {

            expect(error.message).to.include('UnauthorizedAccount');
            return;
        }

    });

    it('Should update  V3 pool feed by owner', async function () {
        await cdfiSubscription.connect(deployer).updateV3Pools(chainId, mockPool.target);
        const updatedV3Pools = await cdfiSubscription.uniswapV3PoolAddresses(chainId);
        expect(updatedV3Pools).to.equal(mockPool.target);

    });
    it('should revert if non-owner tries to update V3 pool price feed address', async function () {
        try {
            await cdfiSubscription.connect(addr1).updateV3Pools(chainId, mockPool.target);
        } catch (error) {

            expect(error.message).to.include('UnauthorizedAccount');
            return;
        }

    });

    it('should allow a user to buy a subscription with native currency', async function () {
        const tokenId = 0;
        const uri = 'metadata_uri';
        const additionalUri = 'extended_metadata_uri';

        await cdfiSubscription.connect(deployer).updateChainlinkPriceFeed(chainId, mockChainlinkAggregator.target);
        const subscriptionPriceUSD = ethers.parseUnits("400", 18);
        const expectedUSDValue = subscriptionPriceUSD;

        const tx = await cdfiSubscription.connect(addr1).buySubWithNative(tokenId, uri, additionalUri, { value: expectedUSDValue });
        await tx.wait();


        const ownerOfToken = await cdfiSubscription.ownerOf(tokenId);
        expect(ownerOfToken).to.equal(addr1.address);

        const tokenURI = await cdfiSubscription.tokenURI(tokenId);
        expect(tokenURI).to.equal(uri);
        const additionalURI = await cdfiSubscription.getAdditionalURI(tokenId);
        expect(additionalURI).to.equal(additionalUri);
    });

    it('should revert if native value sent is less than the subscription price', async function () {
        const tokenId = 0;
        const uri = 'metadata_uri';
        const additionalUri = 'extended_metadata_uri';

        await cdfiSubscription.connect(deployer).updateChainlinkPriceFeed(chainId, mockChainlinkAggregator.target);

        const subscriptionPriceUSD = ethers.parseUnits("0.00001", 18);

        const txPromise = cdfiSubscription.connect(addr1).buySubWithNative(tokenId, uri, additionalUri, { value: subscriptionPriceUSD });

        await expect(txPromise).to.be.revertedWith("Native value should be equal or bigger subscription price!");
    });
    it('should revert if sending excess amount fails', async function () {
        const tokenId = 0;
        const uri = 'metadata_uri';
        const additionalUri = 'extended_metadata_uri';

        await cdfiSubscription.connect(deployer).updateChainlinkPriceFeed(chainId, mockChainlinkAggregator.target);

        const subscriptionPriceUSD = ethers.parseUnits("400", 18);

        const expectedUSDValue = subscriptionPriceUSD + ethers.parseEther("1");

        const tx = await cdfiSubscription.connect(addr1).buySubWithNative(tokenId, uri, additionalUri, { value: expectedUSDValue });

        const receipt = await tx.wait();

        expect(receipt.status).to.equal(1);
        const sent = receipt.logs.find(log => log.event === 'Failed' && log.args.error === "Failed to send excess amount");
        expect(sent).to.be.undefined;
    });


    it('should allow a user to buy a subscription with CDFi currency', async function () {
        const tokenId = 0;
        const uri = 'metadata_uri';
        const additionalUri = 'extended_metadata_uri';

        await cdfiSubscription.connect(deployer).updateV3Pools(chainId, mockPool.target);

        const tx = await cdfiSubscription.connect(addr1).buySubWithCDFi(tokenId, uri, additionalUri);
        await tx.wait();

        const ownerOfToken = await cdfiSubscription.ownerOf(tokenId);
        expect(ownerOfToken).to.equal(addr1.address);

        const tokenURI = await cdfiSubscription.tokenURI(tokenId);
        expect(tokenURI).to.equal(uri);
        const additionalURI = await cdfiSubscription.getAdditionalURI(tokenId);
        expect(additionalURI).to.equal(additionalUri);
    });

    it('should revert if Pool does not exist for getting subscription with CDFi token', async function () {
        const tokenId = 0;
        const uri = 'metadata_uri';
        const additionalUri = 'extended_metadata_uri';
        try {
            await cdfiSubscription.connect(addr1).buySubWithCDFi(tokenId, uri, additionalUri);
        } catch (error) {

            expect(error.message).to.include('Pool does not exist.');
            return;
        }

    });

    it('should allow buying subscription with stablecoin', async function () {
        const tokenId = 1;
        const uri = 'metadata_uri';
        const additionalUri = 'extended_metadata_uri';
        const usdAmount = ethers.parseUnits("400", 18);
        await mockUSDT.mint(addr1.address, usdAmount);
        await mockUSDT.connect(addr1).approve(cdfiSubscription.target, usdAmount);
        const tx = await cdfiSubscription.connect(addr1).buySubWithStable(
            mockUSDT.target,
            usdAmount,
            tokenId,
            uri,
            additionalUri
        );
        const receipt = await tx.wait();
        expect(receipt.status).to.equal(1);

    });
    it('should allow buying subscription with stablecoin', async function () {
        const tokenId = 1;
        const uri = 'metadata_uri';
        const additionalUri = 'extended_metadata_uri';
        const usdAmount = ethers.parseUnits("400", 18);
        await mockUSDT.mint(addr1.address, usdAmount);
        await mockUSDT.connect(addr1).approve(cdfiSubscription.target, usdAmount);
        const tx = await cdfiSubscription.connect(addr1).buySubWithStable(
            mockUSDT.target,
            usdAmount,
            tokenId,
            uri,
            additionalUri
        );
        const receipt = await tx.wait();
        expect(receipt.status).to.equal(1);

    });

    it('should revert with Invalid stable address during buying subscription with stablecoin', async function () {
        const tokenId = 1;
        const uri = 'metadata_uri';
        const additionalUri = 'extended_metadata_uri';
        const usdAmount = ethers.parseUnits("400", 18);
        await mockUSDT.mint(addr1.address, usdAmount);
        await mockUSDT.connect(addr1).approve(cdfiSubscription.target, usdAmount);

        try {
            await cdfiSubscription.connect(addr1).buySubWithStable(
                priceFeedAddress,
                usdAmount,
                tokenId,
                uri,
                additionalUri
            );
        } catch (error) {

            expect(error.message).to.include('Invalid stable address');
            return;
        }

    });
    it('should revert with Stable amount should be equal subscription price during buying subscription with stablecoin', async function () {
        const tokenId = 1;
        const uri = 'metadata_uri';
        const additionalUri = 'extended_metadata_uri';
        const usdAmount = ethers.parseUnits("0.01", 18);
        await mockUSDT.mint(addr1.address, usdAmount);
        await mockUSDT.connect(addr1).approve(cdfiSubscription.target, usdAmount);

        try {
            await cdfiSubscription.connect(addr1).buySubWithStable(
                mockUSDT.target,
                usdAmount,
                tokenId,
                uri,
                additionalUri
            );
        } catch (error) {

            expect(error.message).to.include('Stable amount should be equal subscription price!');
            return;
        }

    });
    it('Withdraws all USDT, USDC, and CDFi tokens from the contract to a specified receiver', async function () {
        const tokenAmount = ethers.parseUnits("400", 18);
        await mockUSDT.mint(cdfiSubscription.target, tokenAmount);
        await mockUSDC.mint(cdfiSubscription.target, tokenAmount);
        await mockCDFi.mint(cdfiSubscription.target, tokenAmount);

        const tx = await cdfiSubscription.connect(deployer).withdraw(deployer.address);
        await expect(tx)
            .to.emit(cdfiSubscription, 'USDTWithdrawn')
            .withArgs(deployer.address, tokenAmount);

        await expect(tx)
            .to.emit(cdfiSubscription, 'USDCWithdrawn')
            .withArgs(deployer.address, tokenAmount);

        await expect(tx)
            .to.emit(cdfiSubscription, 'CDFiWithdrawn')
            .withArgs(deployer.address, tokenAmount);
    });
    it('Should allow changing the address for the USDT token.', async function () {
        const tx = cdfiSubscription.connect(deployer).changeUSDTAddress("0x1234567890123456789012345678901234567890");

        await expect(tx)
            .to.emit(cdfiSubscription, 'AddressUSDTChanged')
            .withArgs("0x1234567890123456789012345678901234567890");
    });

    it('Should allow changing the address for the USDC token.', async function () {
        const tx = cdfiSubscription.connect(deployer).changeUSDCAddress("0x1234567890123456789012345678901234567890");

        await expect(tx)
            .to.emit(cdfiSubscription, 'AddressUSDCChanged')
            .withArgs("0x1234567890123456789012345678901234567890");
    });
    it('Should allow changing the address for the CDFi token.', async function () {
        const tx = cdfiSubscription.connect(deployer).changeCDFiAddress("0x1234567890123456789012345678901234567890");

        await expect(tx)
            .to.emit(cdfiSubscription, 'AddressCDFiChanged')
            .withArgs("0x1234567890123456789012345678901234567890");
    });

    it('Sets the maximum supply of subscriptions', async function () {
        const tokenAmount = ethers.parseUnits("400", 18);
        const tx = cdfiSubscription.connect(deployer).setMaxSupply(tokenAmount);

        await expect(tx)
            .to.emit(cdfiSubscription, 'MaxSupplyChanged')
            .withArgs(tokenAmount);
    });
    it('Should revert with New max supply must be greater than minted count during setting max supply', async function () {
        const tokenAmount = ethers.parseUnits("0", 18);

        try {
            cdfiSubscription.connect(deployer).setMaxSupply(tokenAmount);
        } catch (error) {

            expect(error.message).to.include('New max supply must be greater than minted count');
            return;
        }
    });

    it('Should sets the discount for buying subscriptions with CDFi tokens and the base CDFi price', async function () {
        const discount = 40;

        const tx = cdfiSubscription.connect(deployer).setCDFiDiscount(discount);

        await expect(tx)
            .to.emit(cdfiSubscription, 'CDFiDiscountChanged')
            .withArgs(discount);
    });

    it('Should revet with Discount must be less than 100 if disount is more than 100', async function () {
        const discount = 140;

        try {
            cdfiSubscription.connect(deployer).setCDFiDiscount(discount);
        } catch (error) {

            expect(error.message).to.include('Discount must be less than 100');
            return;
        }
    });
    it('Should sets the subscription price in USD', async function () {
        const tokenAmount = ethers.parseUnits("400", 18);

        const tx = cdfiSubscription.connect(deployer).setSubPrice(tokenAmount);

        await expect(tx)
            .to.emit(cdfiSubscription, 'PriceChanged')
            .withArgs(tokenAmount);
    });

    it('hould returns the additional URI for a given token ID', async function () {

        const tokenId = 0;
        const uri = 'metadata_uri';
        const additionalUri = 'extended_metadata_uri';

        await cdfiSubscription.connect(deployer).updateV3Pools(chainId, mockPool.target);

        await cdfiSubscription.connect(addr1).buySubWithCDFi(tokenId, uri, additionalUri);

        const tx = await cdfiSubscription.getAdditionalURI(tokenId);

        expect(tx).to.equal(additionalUri)

    });

    it('Should withdraw ETH to a specified address', async function () {
        const requiredBalance = ethers.parseEther('1');

        await deployer.sendTransaction({
            to: cdfiSubscription.target,
            value: requiredBalance.toString(),
        });
        const receiverAddress = addr1.address;
        const initialReceiverBalance = await ethers.provider.getBalance(receiverAddress);

        const tx = await cdfiSubscription.connect(deployer).withdrawEther(receiverAddress);
        await tx.wait();

        expect(tx)
            .to.emit(cdfiSubscription, 'NativeWithdrawn')
            .withArgs(receiverAddress, requiredBalance);

        const finalReceiverBalance = await ethers.provider.getBalance(receiverAddress);
        expect(finalReceiverBalance - initialReceiverBalance).to.equal(requiredBalance);
    });

    it('Should revert with No ether left to withdraw', async function () {
        const requiredBalance = ethers.parseEther('1');

        try {
            cdfiSubscription.connect(deployer).withdrawEther(requiredBalance);
        } catch (error) {

            expect(error.message).to.include('No ether left to withdraw');
            return;
        }
    });

    it('Should retrieves the current native currency price in USD from the Chainlink price feed.', async function () {

        await cdfiSubscription.connect(deployer).updateChainlinkPriceFeed(chainId, mockChainlinkAggregator.target);
        const tx = await cdfiSubscription.connect(addr1).getNativePrice();

        expect(tx).to.equal(300000000000n);

    });
    it('should calculate the price in CDFi tokens correctly', async function () {
        await cdfiSubscription.connect(deployer).updateV3Pools(chainId, mockPool.target);
        await cdfiSubscription.uniswapV3PoolAddresses(chainId);
        const result = await cdfiSubscription.getPriceInCDFi();
        expect(result).to.equal(0);
    });

});






