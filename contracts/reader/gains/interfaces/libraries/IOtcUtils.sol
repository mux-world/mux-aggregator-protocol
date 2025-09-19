// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/IOtc.sol";

/**
 * @dev Interface for GNSOtc facet (inherits types and also contains functions, events, and custom errors)
 */
interface IOtcUtils is IOtc {
    /**
     * @dev Initializer for OTC facet
     * @param _config new OTC Config
     */
    function initializeOtc(IOtcUtils.OtcConfig memory _config) external;

    /**
     * @dev Updates OTC config
     * @param _config new OTC Config. Sum of `treasuryShareP`, `stakingShareP`, `burnShareP` must equal 100 and `premiumP` must be less than or equal to MAX_PREMIUM_P
     */
    function updateOtcConfig(IOtcUtils.OtcConfig memory _config) external;

    /**
     * @dev Increases OTC balance for a collateral
     * @param _collateralIndex collateral index
     * @param _collateralAmount amount of collateral to increase (collateral precision)
     */
    function addOtcCollateralBalance(uint8 _collateralIndex, uint256 _collateralAmount) external;

    /**
     * @dev OTC Buys GNS from caller for `_amountCollateral` of `_collateralIndex`.
     * When collateral is GNS, no tokens are transferred to or from the caller and no premium is paid.
     *
     * @param _collateralIndex collateral index
     * @param _collateralAmount amount of collateral to trade (collateral precision)
     */
    function sellGnsForCollateral(uint8 _collateralIndex, uint256 _collateralAmount) external;

    /**
     * @dev Returns OTC Config
     */
    function getOtcConfig() external view returns (IOtcUtils.OtcConfig memory);

    /**
     * @dev Returns OTC balance for a collateral (collateral precision)
     * @param _collateralIndex collateral index
     */
    function getOtcBalance(uint8 _collateralIndex) external view returns (uint256);

    /**
     * @dev Returns OTC rate (price + premium) of GNS in collateral (1e10)
     * @param _collateralIndex collateral index
     */
    function getOtcRate(uint8 _collateralIndex) external view returns (uint256);

    /**
     * @dev Emitted when OTCConfig is updated
     * @param config new OTC config
     */
    event OtcConfigUpdated(IOtcUtils.OtcConfig config);

    /**
     * @dev Emitted when OTC balance is updated
     * @param collateralIndex collateral index
     * @param balanceCollateral new balance (collateral precision)
     */
    event OtcBalanceUpdated(uint8 indexed collateralIndex, uint256 balanceCollateral);

    /**
     * @dev Emitted when an OTC trade is executed
     * @param collateralIndex collateral index
     * @param collateralAmount amount of collateral traded (collateral precision)
     * @param gnsPriceCollateral effective gns/collateral price, including premium (1e10)
     * @param treasuryAmountGns amount of GNS sent to treasury (1e18)
     * @param stakingAmountGns amount of GNS sent to GNS Staking (1e18)
     * @param burnAmountGns amount of GNS burned (1e18)
     */
    event OtcExecuted(
        uint8 indexed collateralIndex,
        uint256 collateralAmount,
        uint256 gnsPriceCollateral,
        uint256 treasuryAmountGns,
        uint256 stakingAmountGns,
        uint256 burnAmountGns
    );

    error InvalidShareSum();
}
