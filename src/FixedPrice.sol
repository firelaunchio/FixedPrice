// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@solady/src/utils/Clone.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@solady/src/utils/FixedPointMathLib.sol";
import "@solady/src/utils/MerkleProofLib.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./utils/Pausable.sol";

contract FixedPrice is Pausable, Clone, ReentrancyGuard {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;
    using MerkleProofLib for bytes32[];

    uint256 public totalSales;
    bool public success;
    bool public closed;
    mapping(address => uint256) public purchasedShares;
    mapping(address => uint256) public purchasedAssets;

    error WhitelistProof();
    error BuyLimitExceeded();
    error TradingDisallowed();
    error ClosingDisallowed();
    error RedeemingDisallowed();
    error CallerDisallowed();
    error AlreadyInit();
    error HardCapExceeded();
    error ShareBalanceOf();

    event Buy(address indexed account, uint256 assetsIn, uint256 sharesOut);
    event Redeem(address indexed account, uint256 shares);

    /// @notice The address of the asset token.
    /// @dev This is the ERC20 token representing the asset in the pool.
    /// @return The address of the asset token.
    function asset() public pure virtual returns (address) {
        return _getArgAddress(0);
    }

    /// @notice The address of the share token.
    /// @dev This is the ERC20 token representing the shares in the pool.
    /// @return The address of the share token.
    function share() public pure virtual returns (address) {
        return _getArgAddress(20);
    }

    /// @notice The address of the platform where fees are collected.
    /// @dev This is the address where fees are collected.
    /// @return The address of the platform.
    function platform() public pure virtual returns (address) {
        return _getArgAddress(40);
    }

    /// @notice The address of the manager who controls the pool.
    /// @dev This is the address who has control over the pool's privledged operations.
    /// @return The address of the manager.
    function manager() public pure virtual returns (address) {
        return _getArgAddress(60);
    }

    /// @notice The share token price.
    /// @dev This value represents the share token price.
    /// @return The share token price.
    function price() public pure virtual returns (uint256) {
        return _getArgUint88(80);
    }

    /// @notice buying limits share token per user.
    /// @dev This value represents buying limits.
    /// @return buying limits share token per user.
    function buyLimit() public pure virtual returns (uint256) {
        return _getArgUint88(91);
    }

    /// @notice The share token soft cap.
    /// @dev This value represents soft cap.
    /// @return The share token soft cap.
    function softCap() public pure virtual returns (uint256) {
        return _getArgUint88(102);
    }

    /// @notice The share token hard cap.
    /// @dev This value represents hard cap.
    /// @return The share token hard cap.
    function hardCap() public pure virtual returns (uint256) {
        return _getArgUint88(113);
    }

    /// @notice The sale start timestamp.
    /// @dev This timestamp represents when the sale of shares in the pool starts.
    /// @return The sale start timestamp.
    function saleStart() public pure virtual returns (uint256) {
        return _getArgUint40(124);
    }

    /// @notice The sale end timestamp.
    /// @dev This timestamp represents when the sale of shares in the pool ends.
    /// @return The sale end timestamp.
    function saleEnd() public pure virtual returns (uint256) {
        return _getArgUint40(129);
    }

    /// @notice The platform fee percentage.
    /// @dev This percentage represents the fee collected by the platform on transactions.
    /// @return The platform fee percentage.
    function platformFee() public pure virtual returns (uint256) {
        return _getArgUint64(134);
    }

    /// @notice The Merkle root for the whitelist.
    /// @dev This is the Merkle root used for whitelisting addresses.
    /// @return The Merkle root for the whitelist.
    function whitelistMerkleRoot() public pure virtual returns (bytes32) {
        return _getArgBytes32(142);
    }

    /// @notice Check if the whitelist is enabled.
    /// @dev This flag indicates whether the whitelist is enabled.
    /// @return True if the whitelist is enabled, false otherwise.
    function whitelisted() public pure virtual returns (bool) {
        return whitelistMerkleRoot() != 0;
    }

    /// @notice Modifier to restrict access to whitelisted addresses.
    /// @dev This modifier checks if the caller's address is whitelisted using a Merkle proof.
    modifier onlyWhitelisted(bytes32[] memory proof) virtual {
        if (whitelisted()) {
            if (!proof.verify(whitelistMerkleRoot(), keccak256(abi.encodePacked(msg.sender)))) {
                revert WhitelistProof();
            }
        }
        _;
    }

    /// @notice Modifier to check if the sale is active.
    /// @dev This modifier checks if the current timestamp is within the sale period.
    modifier whenSaleActive() virtual {
        if (block.timestamp < saleStart() || block.timestamp >= saleEnd()) {
            revert TradingDisallowed();
        }
        _;
    }

    function buyShares(uint256 assets) external returns (uint256 sharesOut) {
        return buyShares(assets, MerkleProofLib.emptyProof());
    }

    function buyShares(
        uint256 assets,
        bytes32[] memory proof
    )
        public
        virtual
        whenNotPaused
        whenSaleActive
        onlyWhitelisted(proof)
        nonReentrant
        returns (uint256 sharesOut)
    {
        asset().safeTransferFrom(msg.sender, address(this), assets);

        sharesOut = previewSharesOut(assets);
        uint256 purchasedSharesAfter = purchasedShares[msg.sender] + sharesOut;
        if (purchasedSharesAfter > buyLimit()) {
            revert BuyLimitExceeded();
        }
        uint256 totalSalesAfter = totalSales + sharesOut;
        if (totalSalesAfter > hardCap()) {
            revert HardCapExceeded();
        }

        purchasedShares[msg.sender] = purchasedSharesAfter;
        purchasedAssets[msg.sender] += assets;
        totalSales = totalSalesAfter;

        emit Buy(msg.sender, assets, sharesOut);
    }

    // close project.
    function close() external {
        if (closed) revert ClosingDisallowed();
        if (block.timestamp < saleEnd()) revert ClosingDisallowed();

        if (totalSales >= softCap()) {
            success = true;

            uint256 totalShares = share().balanceOf(address(this));
            if (totalShares < totalSales) {
                revert ShareBalanceOf();
            } else if (totalShares > totalSales) {
                uint256 unsoldShares = totalShares.rawSub(totalSales);
                share().safeTransfer(manager(), unsoldShares);
            }

            uint256 totalAssets = asset().balanceOf(address(this));
            uint256 platformFees = totalAssets.mulWad(platformFee());
            uint256 totalAssetsMinusFees = totalAssets.rawSub(platformFees);
            if (totalAssets != 0) {
                asset().safeTransfer(platform(), platformFees);
                asset().safeTransfer(manager(), totalAssetsMinusFees);
            }
        } else {
            uint256 totalShares = share().balanceOf(address(this));
            if (totalShares != 0) {
                share().safeTransfer(manager(), totalShares);
            }
        }

        closed = true;
    }
    // user claim project token after project close.

    function redeem(address recipient) external returns (uint256) {
        if (!closed) revert RedeemingDisallowed();
        if (success) {
            uint256 shares = purchasedShares[msg.sender];
            delete purchasedShares[msg.sender];
            delete purchasedAssets[msg.sender];

            if (shares != 0) {
                share().safeTransfer(recipient, shares);
                emit Redeem(msg.sender, shares);
            }
            return shares;
        } else {
            uint256 assets = purchasedAssets[msg.sender];
            delete purchasedAssets[msg.sender];
            delete purchasedShares[msg.sender];

            if (assets != 0) {
                asset().safeTransfer(recipient, assets);
                emit Redeem(msg.sender, assets);
            }
            return assets;
        }
    }

    function shareBalanceOf() external view returns (uint256) {
        return share().balanceOf(address(this));
    }

    function assetBalanceOf() external view returns (uint256) {
        return asset().balanceOf(address(this));
    }

    // in: amount of assets
    // out: amount of shares.
    function previewSharesOut(uint256 assetsIn) public view virtual returns (uint256) {
        return 1e18 * assetsIn / price();
    }

    function args() public view virtual returns (Sale memory) {
        return Sale(
            asset(),
            share(),
            asset().balanceOf(address(this)),
            share().balanceOf(address(this)),
            saleStart(),
            saleEnd(),
            price(),
            buyLimit(),
            totalSales,
            ERC20(asset()).decimals(),
            ERC20(asset()).decimals()
        );
    }
}

struct Sale {
    address asset;
    address share;
    uint256 assets;
    uint256 shares;
    uint256 saleStart;
    uint256 saleEnd;
    uint256 pirce;
    uint256 buyLimit;
    uint256 totalSales;
    uint8 assetDecimals;
    uint8 shareDecimals;
}
