// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import "@solady/src/auth/Ownable.sol";
import "@solady/src/utils/LibClone.sol";

struct StableSettings {
    address asset;
    address share;
    address creator;
    uint88 price;
    uint88 buyLimit;
    uint88 softCap;
    uint88 hardCap;
    uint40 saleStart;
    uint40 saleEnd;
    bytes32 whitelistMerkleRoot;
}

struct StableFactorySettings {
    address feeRecipient;
    uint48 platformFee;
}

uint256 constant MAX_FEE_BIPS = 0.1e4;

contract StableSaleFactory is Ownable {
    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emitted when a new Liquidity Pool is created.
    /// @param pool The address of the newly created Liquidity Bootstrap Pool.
    event PoolCreated(address pool);

    /// @dev Emitted when the fee recipient address is updated.
    /// @param recipient The new fee recipient address.
    event FeeRecipientSet(address recipient);

    /// @dev Emitted when the platform fee is updated.
    /// @param fee The new platform fee value.
    event PlatformFeeSet(uint256 fee);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    /// @dev Error thrown when the maximum fee is exceeded.
    error MaxFeeExceeded();

    /// @dev Error thrown when the sale period is too low.
    error SalePeriodLow();

    /// @dev Error thrown when the asset or share address is invalid.
    error InvalidAssetOrShare();

    /// @dev Error thrown when the sale hardcap is too low.
    error InvalidCapConfig();

    /// -----------------------------------------------------------------------
    /// Mutable Storage
    /// -----------------------------------------------------------------------

    /// @notice Storage for factory-specific settings.
    StableFactorySettings public factorySettings;

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    /// @dev Immutable storage for the implementation address of Liquidity Pools.
    address internal immutable implementation;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// @param _implementation The address of the Liquidity Pool implementation contract.
    /// @param _owner The owner of the factory contract.
    /// @param _feeRecipient The address that will receive platform and referrer fees.
    /// @param _platformFee The platform fee, represented as a fraction with a denominator of 10,000.
    constructor(address _implementation, address _owner, address _feeRecipient, uint48 _platformFee) {
        // Check that the platform and referrer fees are within the allowed range.
        if (_platformFee > MAX_FEE_BIPS) revert MaxFeeExceeded();

        // Initialize the owner and implementation address.
        _initializeOwner(_owner);
        implementation = _implementation;

        // Set the initial factory settings including fee recipient and fees.
        factorySettings = StableFactorySettings(_feeRecipient, _platformFee);

        // Emit events for the initial fee settings.
        emit FeeRecipientSet(_feeRecipient);
        emit PlatformFeeSet(_platformFee);
    }

    /// -----------------------------------------------------------------------
    /// Creation Logic
    /// -----------------------------------------------------------------------

    /// @notice Creates a new Liquidity Pool with the provided settings and parameters.
    /// @param salt The salt value for deterministic pool creation.
    /// @return pool The address of the newly created Liquidity Bootstrap Pool.
    function createIDOPool(StableSettings memory args, bytes32 salt) external virtual returns (address pool) {
        if (args.share == args.asset || args.share == address(0) || args.asset == address(0)) {
            revert InvalidAssetOrShare();
        }

        // Check timestamps to ensure the sale will not immediately end.
        if (uint40(block.timestamp + 1 days) > args.saleEnd || args.saleEnd - args.saleStart < uint40(1 days)) {
            revert SalePeriodLow();
        }

        if (args.softCap > args.hardCap || args.buyLimit > args.hardCap) {
            revert InvalidCapConfig();
        }

        pool = implementation.cloneDeterministic(_encodeImmutableArgs(args), salt);

        emit PoolCreated(pool);
    }

    /// -----------------------------------------------------------------------
    /// Settings Modification Logic
    /// -----------------------------------------------------------------------

    /// @notice Sets the fee recipient address.
    /// @param recipient The new fee recipient address.
    function setFeeRecipient(address recipient) external virtual onlyOwner {
        factorySettings.feeRecipient = recipient;

        emit FeeRecipientSet(recipient);
    }

    /// @notice Sets the platform fee percentage.
    /// @param fee The new platform fee value, represented as a fraction with a denominator of 10,000.
    function setPlatformFee(uint48 fee) external virtual onlyOwner {
        if (fee > MAX_FEE_BIPS) revert MaxFeeExceeded();

        factorySettings.platformFee = fee;

        emit PlatformFeeSet(fee);
    }

    /// @notice Modifies multiple factory settings at once.
    /// @param feeRecipient The new fee recipient address.
    /// @param platformFee The new platform fee value, represented as a fraction with a denominator of 10,000.
    function modifySettings(address feeRecipient, uint48 platformFee) external virtual onlyOwner {
        if (platformFee > MAX_FEE_BIPS) revert MaxFeeExceeded();

        factorySettings = StableFactorySettings(feeRecipient, platformFee);

        emit FeeRecipientSet(feeRecipient);
        emit PlatformFeeSet(platformFee);
    }

    /// -----------------------------------------------------------------------
    /// Factory Helper Logic
    /// -----------------------------------------------------------------------

    /// @notice Predicts the deterministic address of a Liquidity Bootstrap Pool.
    /// @param args The StableSettings struct containing pool-specific parameters.
    /// @param salt The salt value for deterministic pool creation.
    /// @return The deterministic address of the pool.
    function predictDeterministicAddress(
        StableSettings memory args,
        bytes32 salt
    )
        external
        view
        virtual
        returns (address)
    {
        return implementation.predictDeterministicAddress(_encodeImmutableArgs(args), salt, address(this));
    }

    /// @notice Predicts the init code hash for a Liquidity Bootstrap Pool.
    /// @param args The StableSettings struct containing pool-specific parameters.
    /// @return The init code hash of the pool.
    function predictInitCodeHash(StableSettings memory args) external view virtual returns (bytes32) {
        return implementation.initCodeHash(_encodeImmutableArgs(args));
    }

    function _encodeImmutableArgs(StableSettings memory args) internal view virtual returns (bytes memory) {
        StableFactorySettings memory settings = factorySettings;
        unchecked {
            return abi.encodePacked(
                // forgefmt: disable-start
                abi.encodePacked(
                    args.asset,
                    args.share,
                    settings.feeRecipient,
                    args.creator
                ),
                abi.encodePacked(
                    args.price,
                    args.buyLimit,
                    args.softCap,
                    args.hardCap
                ),
                abi.encodePacked(
                    args.saleStart,
                    args.saleEnd
                ),
                abi.encodePacked(
                    uint64(settings.platformFee) * 1e14,
                    args.whitelistMerkleRoot
                )
            );// forgefmt: disable-end
        }
    }
}
