// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract IERC20Extended is IERC20 {
    function decimals() public view virtual returns (uint8);
}

/**
 * @title CDFiSubscription
 */
contract CDFiSubscription is ERC721URIStorage, Ownable {
    using SafeERC20 for ERC20;

    uint256 public constant HOUR = 3600;
    uint256 public constant MULTIPLIER = 1e8; //chainlink price multiplier
    uint256 public priceInUsd = 400;
    uint256 public maxSupply = 10000;
    uint256 public totalMinted;

    address public addressUSDT;
    address public addressUSDC;
    address public addressCDFi;

    // discount calculate in percents
    uint256 public discount = 95; // %

    mapping(uint256 => address) public priceFeedAddresses;
    mapping(uint256 => address) public uniswapV3PoolAddresses;
    mapping(uint256 => uint8) private _tokenIds;
    mapping(uint256 => string) private _additionalURIs;
    mapping(address => bool) private _hasMinted;

    event MaxSupplyChanged(uint256 indexed newSupply);
    event PriceChanged(uint256 indexed newPrice);
    event PriceInCDFiChanged(uint256 indexed newPrice);
    event PriceFeedChanged(
        uint256 indexed chainId,
        address indexed priceFeedAddress
    );
    event USDTWithdrawn(address indexed receiver, uint256 indexed amount);
    event USDCWithdrawn(address indexed receiver, uint256 indexed amount);
    event CDFiWithdrawn(address indexed receiver, uint256 indexed amount);
    event AddressUSDTChanged(address indexed newUSDTAddress);
    event AddressUSDCChanged(address indexed newUSDCAddress);
    event AddressCDFiChanged(address indexed newCDFiAddress);
    event NativeWithdrawn(address indexed receiver, uint256 indexed amount);
    event CDFiDiscountChanged(uint256 indexed discount);

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     * Also sets the addresses for USDT, USDC, CDFi tokens, and the owner of the contract.
     * It requires that none of these addresses are the zero address.
     */
    constructor(
        address addressUSDT_,
        address addressUSDC_,
        address addressCDFi_,
        address owner_,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) Ownable(owner_) {
        require(addressUSDT_ != address(0x0), "Zero address!");
        addressUSDT = addressUSDT_;
        require(addressUSDC_ != address(0x0), "Zero address!");
        addressUSDC = addressUSDC_;
        require(addressCDFi_ != address(0x0), "Zero address!");
        addressCDFi = addressCDFi_;
        _configureChainlinkPriceFeed();
        _configureV3PoolAddresses();
    }

    /**
     * @dev Updates the Chainlink price feed address for a specific chain ID. Only callable by the owner.
     * Emits a `PriceFeedChanged` event.
     * @param chainId The chain ID for which the price feed address is being updated.
     * @param priceFeedAddress The new price feed address.
     */
    function updateChainlinkPriceFeed(
        uint256 chainId,
        address priceFeedAddress
    ) external onlyOwner {
        require(priceFeedAddress != address(0x0), "Zero address");
        priceFeedAddresses[chainId] = priceFeedAddress;
        emit PriceFeedChanged(chainId, priceFeedAddress);
    }

    /**
     * @dev Updates the V3Pool price feed address for a specific chain ID. Only callable by the owner.
     * Emits a `PriceFeedChanged` event.
     * @param chainId The chain ID for which the price feed address is being updated.
     * @param v3PoolAddress The new price feed address.
     */
    function updateV3Pools(
        uint256 chainId,
        address v3PoolAddress
    ) external onlyOwner {
        require(v3PoolAddress != address(0x0), "Zero address");
        address token0 = IUniswapV3Pool(v3PoolAddress).token0();
        address token1 = IUniswapV3Pool(v3PoolAddress).token1();
        require(
            addressCDFi == token0 || addressCDFi == token1,
            "Pool does not contain CDFi in itself."
        );
        uniswapV3PoolAddresses[chainId] = v3PoolAddress;
        emit PriceFeedChanged(chainId, v3PoolAddress);
    }

    /**
     * @dev Allows a user to buy a subscription with native currency (e.g., ETH).
     * The value sent with the transaction is converted to USD using the Chainlink price feed.
     * Requires that the USD value is greater or equal to the subscription price.
     * @param tokenId The token ID for the subscription.
     * @param uri The URI for the subscription metadata.
     * @param additionalUri Additional URI for extended metadata.
     * @return bool Returns true if the subscription purchase is successful.
     */
    function buySubWithNative(
        uint256 tokenId,
        string memory uri,
        string memory additionalUri
    ) external payable returns (bool) {
        uint256 usdValue = (msg.value * getNativePrice()) / MULTIPLIER;
        require(
            usdValue >= priceInUsd * 1e18, 
            "Native value should be equal or bigger subscription price!"
        );
        _mintSubWithMetadata(_msgSender(), tokenId, uri, additionalUri);
        return true;
    }

    /**
     * @dev Placeholder for buying a subscription with CDFi tokens. Currently returns true without any logic.
     * @param tokenId The token ID for the subscription.
     * @param uri The URI for the subscription metadata.
     * @param additionalUri Additional URI for extended metadata.
     * @return bool Returns true.
     */
    function buySubWithCDFi(
        uint256 tokenId,
        string memory uri,
        string memory additionalUri
    ) external returns (bool) {
        uint256 priceInCDFi = getPriceInCDFi();
        ERC20(addressCDFi).safeTransferFrom(
            msg.sender,
            address(this),
            priceInCDFi
        );
        _mintSubWithMetadata(_msgSender(), tokenId, uri, additionalUri);
        return true;
    }

    /**
     * @dev Allows a user to buy a subscription with a stablecoin (USDT or USDC).
     * Requires that the stablecoin amount is equal to the subscription price.
     * @param tokenAddress The address of the stablecoin token.
     * @param usdAmount The amount of stablecoin, adjusted for decimals.
     * @param tokenId The token ID for the subscription.
     * @param uri The URI for the subscription metadata.
     * @param additionalUri Additional URI for extended metadata.
     * @return bool Returns true if the subscription purchase is successful.
     */
    function buySubWithStable(
        address tokenAddress,
        uint256 usdAmount,
        uint256 tokenId,
        string memory uri,
        string memory additionalUri
    ) external returns (bool) {
        require(
            tokenAddress == addressUSDT || tokenAddress == addressUSDC,
            "Invalid stable address"
        );
        require(
            usdAmount ==
                priceInUsd * 10 ** IERC20Extended(tokenAddress).decimals(),
            "Stable amount should be equal subscription price!"
        );
        ERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            usdAmount
        );
        _mintSubWithMetadata(_msgSender(), tokenId, uri, additionalUri);
        return true;
    }

    /**
     * @dev Withdraws all USDT, USDC, and CDFi tokens from the contract to a specified receiver. Only callable by the owner.
     * Emits `USDTWithdrawn`, `USDCWithdrawn`, and `CDFiWithdrawn` events.
     * @param receiver The address of the receiver.
     */
    function withdraw(address receiver) external onlyOwner {
        require(receiver != address(0), "Zero address!");
        uint256 amountUSDT = ERC20(addressUSDT).balanceOf(address(this));
        if (amountUSDT > 0) {
            ERC20(addressUSDT).safeTransfer(receiver, amountUSDT);
            emit USDTWithdrawn(receiver, amountUSDT);
        }
        uint256 amountUSDC = ERC20(addressUSDC).balanceOf(address(this));
        if (amountUSDC > 0) {
            ERC20(addressUSDC).safeTransfer(receiver, amountUSDC);
            emit USDCWithdrawn(receiver, amountUSDC);
        }
        uint256 amountCDFi = ERC20(addressCDFi).balanceOf(address(this));
        if (amountCDFi > 0) {
            ERC20(addressCDFi).safeTransfer(receiver, amountCDFi);
            emit CDFiWithdrawn(receiver, amountCDFi);
        }
    }

    /**
     * @dev Withdraws all native currency (e.g., ETH) from the contract to a specified address. Only callable by the owner.
     * Emits a `NativeWithdrawn` event.
     * @param _to The address of the receiver.
     */
    function withdrawEther(address payable _to) external onlyOwner {
        require(_to != address(0x0), "Invalid address");
        uint256 balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");
        (bool sent, ) = _to.call{value: balance}("");
        require(sent, "Failed to send Ether");
        emit NativeWithdrawn(_to, balance);
    }

    /**
     * @dev Changes the address for the USDT token. Only callable by the owner.
     * Emits an `AddressUSDTChanged` event.
     * @param _newAddress The new address for the USDT token.
     */
    function changeUSDTAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0x0), "Zero address!");
        addressUSDT = _newAddress;
        emit AddressUSDTChanged(_newAddress);
    }

    /**
     * @dev Changes the address for the USDC token. Only callable by the owner.
     * Emits an `AddressUSDCChanged` event.
     * @param _newAddress The new address for the USDC token.
     */
    function changeUSDCAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0x0), "Zero address!");
        addressUSDC = _newAddress;
        emit AddressUSDCChanged(_newAddress);
    }
    /**
     * @dev Changes the address for the CDFi token. Only callable by the owner.
     * Emits an `AddressCDFiChanged` event.
     * @param _newAddress The new address for the CDFi token.
     */
    function changeCDFiAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0x0), "Zero address!");
        addressCDFi = _newAddress;
        emit AddressCDFiChanged(_newAddress);
    }
    /**
     * @dev Sets the maximum supply of subscriptions. Only callable by the owner.
     * Requires that the new maximum supply is greater than the total minted subscriptions.
     * Emits a `MaxSupplyChanged` event.
     * @param _newMaxSupply The new maximum supply.
     */
    function setMaxSupply(uint256 _newMaxSupply) external onlyOwner {
        require(
            _newMaxSupply > totalMinted,
            "New max supply must be greater than minted count"
        );
        maxSupply = _newMaxSupply;
        emit MaxSupplyChanged(_newMaxSupply);
    }
    /**
     * @dev Sets the discount for buying subscriptions with CDFi tokens and the base CDFi price. Only callable by the owner.
     * Requires that the discount is less than or equal to 100.
     * Emits a `CDFiDiscountChanged` event.
     * @param _newDiscount The new discount percentage.
     */
    function setCDFiDiscount(uint256 _newDiscount) external onlyOwner {
        require(_newDiscount <= 100, "Discount must be less than 100");
        discount = _newDiscount;
        emit CDFiDiscountChanged(_newDiscount);
    }

    /**
     * @dev Sets the subscription price in USD. Only callable by the owner.
     * Emits a `PriceChanged` event.
     * @param _newPrice The new subscription price in USD.
     */
    function setSubPrice(uint256 _newPrice) external onlyOwner {
        priceInUsd = _newPrice;
        emit PriceChanged(_newPrice);
    }

    /**
     * @dev Returns the additional URI for a given token ID.
     * @param tokenId The token ID.
     * @return string The additional URI.
     */
    function getAdditionalURI(
        uint256 tokenId
    ) external view returns (string memory) {
        return _additionalURIs[tokenId];
    }

    /**
     * @dev Retrieves the current native currency price in USD from the Chainlink price feed.
     * Requires that the price update is less than 1 hour old.
     * @return ethPriceUsd The current price of the native currency in USD.
     */
    function getNativePrice() public view returns (uint256) {
        uint256 chainId = _getChainId();
        (, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(
            priceFeedAddresses[chainId]
        ).latestRoundData();
        require(
            block.timestamp - updatedAt < HOUR,
            "Price update is older than 1 hour!"
        );
        uint256 ethPriceUsd = uint256(answer);
        return ethPriceUsd;
    }

    /// @notice Calculates the price of a subscription in CDFi tokens based on the Uniswap V3 pool price.
    /// @dev This function fetches the current price of CDFi in the specified Uniswap V3 pool and applies a discount.
    /// It supports both cases where CDFi is either token0 or token1 in the pool.
    /// @return result The price of the subscription in CDFi tokens after applying the discount.
    function getPriceInCDFi() public view returns (uint256) {
        uint256 chainId = _getChainId();
        address poolAddress = uniswapV3PoolAddresses[chainId];
        require(poolAddress != address(0x0), "Pool does not exist.");
        address token0 = IUniswapV3Pool(poolAddress).token0();
        address token1 = IUniswapV3Pool(poolAddress).token1();
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(poolAddress)
            .slot0();
        IERC20Extended token0Contract = IERC20Extended(token0);
        IERC20Extended token1Contract = IERC20Extended(token1);
        uint8 decimalsToken0 = token0Contract.decimals();
        uint8 decimalsToken1 = token1Contract.decimals();
        uint256 factor = 10 ** (decimalsToken0 + decimalsToken1);
        uint256 price = (uint256(sqrtPriceX96) *
            uint256(sqrtPriceX96) *
            factor);
        price = price >> 192; //remove precision
        price = price / 10 ** decimalsToken1;
        uint256 result;

        if (token0 == addressCDFi) {
            result = priceInUsd * discount * factor;
            result = result / price / 100;
        }
        if (token1 == addressCDFi) {
            result =
                priceInUsd *
                discount *
                price *
                (10 ** (decimalsToken1 - decimalsToken0));
            result = result / 100; //take 95% from discount;
        }
        return result;
    }

    /**
     * @dev Mints a subscription with metadata to a specified address.
     * Requires that the total minted is less than the max supply, the token ID does not already exist,
     * and the address has not already minted. Sets the token URI and an additional URI for the token.
     * Increments the total minted count.
     * @param to The address to mint the subscription to.
     * @param tokenId The token ID for the new subscription.
     * @param uri The URI for the subscription metadata.
     * @param additionalUri Additional URI for extended metadata.
     */
    function _mintSubWithMetadata(
        address to,
        uint256 tokenId,
        string memory uri,
        string memory additionalUri
    ) private {
        require(totalMinted < maxSupply, "Max supply reached");
        require(_tokenIds[tokenId] != 1, "token ID already exists");
        require(!_hasMinted[to], "Address has already minted");
        _hasMinted[to] = true;
        _tokenIds[tokenId] = 1;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _additionalURIs[tokenId] = additionalUri;
        totalMinted++;
    }

    function _configureChainlinkPriceFeed() private {
        // Ethereum Mainnet ETH/USD
        priceFeedAddresses[1] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        // Binance Smart Chain BNB/USD
        priceFeedAddresses[56] = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
        // Polygon (Matic) MATIC/USD
        priceFeedAddresses[137] = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;
    }

    function _configureV3PoolAddresses() private {
        // Ethereum Mainnet CDFi/USDT
        uniswapV3PoolAddresses[1] = 0x25B2Be69272cAe9ABe33bB6B82491a1Ca91dF153;
        // Binance Smart Chain CDFi/USDT
        uniswapV3PoolAddresses[56] = 0x6639986CBEbe3933Ba97d4510CFD7556e0Db8E2e;
        // Polygon (Matic) CDFi/USDT
        uniswapV3PoolAddresses[
            137
        ] = 0x57aA271dF20bf4D1b80DaD5b04592005e8A194ea;
    }

    function _getChainId() private view returns (uint256) {
        return block.chainid;
    }
}
