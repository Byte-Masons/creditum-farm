// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv2.sol";
import "./interfaces/ISteakHouseV2.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IBeetVault.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "hardhat/console.sol";

/**
 * @dev Deposit TOMB-MAI LP in TShareRewardsPool. Harvest TSHARE rewards and recompound.
 */
contract ReaperStrategyCreditum is ReaperBaseStrategyv2 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    address public constant BEET_VAULT = address(0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce);
    address public constant SPOOKY_ROUTER = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    address public constant SPIRIT_ROUTER = address(0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52);
    address public constant MASTER_CHEF = address(0xe0c43105235C1f18EA15fdb60Bb6d54814299938);

    /**
     * @dev Tokens Used:
     * {WFTM} - Required for liquidity routing when doing swaps.
     * {TSHARE} - Reward token for depositing LP into TShareRewardsPool.
     * {want} - Address of TOMB-MAI LP token. (lowercase name for FE compatibility)
     * {lpToken0} - TOMB (name for FE compatibility)
     * {lpToken1} - MAI (name for FE compatibility)
     */
    address public constant WFTM = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public constant CREDIT = address(0x77128DFdD0ac859B33F44050c6fa272F34872B5E);
    address public constant ANGLE = address(0x3b9e3b5c616A1A038fDc190758Bbe9BAB6C7A857);
    address public constant CUSD = address(0xE3a486C1903Ea794eED5d5Fa0C9473c7D7708f40);
    address public constant AGEUR = address(0x02a2b736F9150d36C0919F3aCEE8BA2A92FBBb40);
    address public constant want = address(0x1b371a952A3246dAc40530D400d86b5d36655ad1);
    address public constant lpToken0 = address(0x02a2b736F9150d36C0919F3aCEE8BA2A92FBBb40);
    address public constant lpToken1 = address(0xE3a486C1903Ea794eED5d5Fa0C9473c7D7708f40);

    /**
     * @dev Paths used to swap tokens:
     * {tshareToWftmPath} - to swap {TSHARE} to {WFTM} (using SPOOKY_ROUTER)
     * {wftmToTombPath} - to swap {WFTM} to {lpToken0} (using SPOOKY_ROUTER)
     * {tombToMaiPath} - to swap half of {lpToken0} to {lpToken1} (using TOMB_ROUTER)
     */
    address[] public tshareToWftmPath;
    address[] public wftmToTombPath;
    address[] public tombToMaiPath;

    // pools used to swap tokens
    bytes32 public constant WFTM_CREDIT_CUSD_POOL = 0x1b1d74a1ab76338653e3aaae79634d6a153d6514000100000000000000000225;
    

    /**
     * @dev Tomb variables
     * {poolId} - ID of pool in which to deposit LP tokens
     */
    uint256 public constant poolId = 2;

    /**
     * @dev Initializes the strategy. Sets parameters and saves routes.
     * @notice see documentation for each variable above its respective declaration.
     */
    function initialize(
        address _vault,
        address[] memory _feeRemitters,
        address[] memory _strategists
    ) public initializer {
        __ReaperBaseStrategy_init(_vault, _feeRemitters, _strategists);
    }

    /**
     * @dev Function that puts the funds to work.
     *      It gets called whenever someone deposits in the strategy's vault contract.
     */
    function _deposit() internal override {
        uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBalance != 0) {
            IERC20Upgradeable(want).safeIncreaseAllowance(MASTER_CHEF, wantBalance);
            ISteakHouseV2(MASTER_CHEF).deposit(poolId, wantBalance);
        }
    }

    /**
     * @dev Withdraws funds and sends them back to the vault.
     */
    function _withdraw(uint256 _amount) internal override {
        uint256 wantBal = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBal < _amount) {
            ISteakHouseV2(MASTER_CHEF).withdraw(poolId, _amount - wantBal);
        }
        IERC20Upgradeable(want).safeTransfer(vault, _amount);
    }

    /**
     * @dev Core function of the strat, in charge of collecting and re-investing rewards.
     *      1. Claims {TSHARE} from the {TSHARE_REWARDS_POOL}.
     *      2. Swaps {TSHARE} to {WFTM} using {SPOOKY_ROUTER}.
     *      3. Claims fees for the harvest caller and treasury.
     *      4. Swaps the {WFTM} token for {lpToken0} using {SPOOKY_ROUTER}.
     *      5. Swaps half of {lpToken0} to {lpToken1} using {TOMB_ROUTER}.
     *      6. Creates new LP tokens and deposits.
     */
    function _harvestCore() internal override {
        _claimRewards();
        _swapRewardsToWftm();
        _swapWFTMToCUSD();
        uint256 cUSDBalance = IERC20Upgradeable(CUSD).balanceOf(address(this));
        console.log("cUSDBalance: ", cUSDBalance);
        _addLiquidity();
        deposit();
    }

    function _claimRewards() internal {
        ISteakHouseV2(MASTER_CHEF).deposit(poolId, 0); // deposit 0 to claim rewards
    }

    function _swapRewardsToWftm() internal {
        address[] memory angleToWftm = new address[](2);
        angleToWftm[0] = ANGLE;
        angleToWftm[1] = WFTM;
        uint256 angleBalance = IERC20Upgradeable(ANGLE).balanceOf(address(this));
        console.log("angleBalance: ", angleBalance);
        _swapUniRouter(angleBalance, angleToWftm, SPOOKY_ROUTER);
        address[] memory creditToWftm = new address[](2);
        creditToWftm[0] = ANGLE;
        creditToWftm[1] = WFTM;
        uint256 creditBalance = IERC20Upgradeable(CREDIT).balanceOf(address(this));
        console.log("creditBalance: ", creditBalance);
        _swapUniRouter(creditBalance, creditToWftm, SPOOKY_ROUTER);
        uint256 wftmBalance = IERC20Upgradeable(WFTM).balanceOf(address(this));
        console.log("wftmBalance: ", wftmBalance);
    }

    /**
     * @dev Core harvest function. Swaps {BEETS} to {WFTM} using {WFTM_BEETS_POOL}.
     */
    function _swapWFTMToCUSD() internal {
        uint256 wftmBalance = IERC20Upgradeable(WFTM).balanceOf(address(this));
        if (wftmBalance == 0) {
            return;
        }

        IBeetVault.SingleSwap memory singleSwap;
        singleSwap.poolId = WFTM_CREDIT_CUSD_POOL;
        singleSwap.kind = IBeetVault.SwapKind.GIVEN_IN;
        singleSwap.assetIn = IAsset(WFTM);
        singleSwap.assetOut = IAsset(CUSD);
        singleSwap.amount = wftmBalance;
        singleSwap.userData = abi.encode(0);

        IBeetVault.FundManagement memory funds;
        funds.sender = address(this);
        funds.fromInternalBalance = false;
        funds.recipient = payable(address(this));
        funds.toInternalBalance = false;

        IERC20Upgradeable(WFTM).safeIncreaseAllowance(BEET_VAULT, wftmBalance);
        IBeetVault(BEET_VAULT).swap(singleSwap, funds, 1, block.timestamp);
    }

    /**
     * @dev Helper function to swap tokens given an {_amount}, swap {_path}, and {_router}.
     */
    function _swapUniRouter(
        uint256 _amount,
        address[] memory _path,
        address _router
    ) internal {
        if (_path.length < 2 || _amount == 0) {
            return;
        }

        IERC20Upgradeable(_path[0]).safeIncreaseAllowance(_router, _amount);
        IUniswapV2Router02(_router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            0,
            _path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of WFTM gained from reward
     */
    function _chargeFees() internal {
        IERC20Upgradeable wftm = IERC20Upgradeable(WFTM);
        uint256 wftmFee = (wftm.balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR;
        if (wftmFee != 0) {
            uint256 callFeeToUser = (wftmFee * callFee) / PERCENT_DIVISOR;
            uint256 treasuryFeeToVault = (wftmFee * treasuryFee) / PERCENT_DIVISOR;
            uint256 feeToStrategist = (treasuryFeeToVault * strategistFee) / PERCENT_DIVISOR;
            treasuryFeeToVault -= feeToStrategist;

            wftm.safeTransfer(msg.sender, callFeeToUser);
            wftm.safeTransfer(treasury, treasuryFeeToVault);
            wftm.safeTransfer(strategistRemitter, feeToStrategist);
        }
    }

    /**
     * @dev Core harvest function. Adds more liquidity using {lpToken0} and {lpToken1}.
     */
    function _addLiquidity() internal {
        uint256 cUSDBal = IERC20Upgradeable(CUSD).balanceOf(address(this));
        address[] memory cUSDToagEUR = new address[](2);
        cUSDToagEUR[0] = CUSD;
        cUSDToagEUR[1] = AGEUR;
        _swapUniRouter(cUSDBal / 2, cUSDToagEUR, SPOOKY_ROUTER);
        uint256 agEURBalance = IERC20Upgradeable(AGEUR).balanceOf(address(this));
        cUSDBal = IERC20Upgradeable(CUSD).balanceOf(address(this));
        console.log("agEURBalance: ", agEURBalance);

        uint256 wantBal = IERC20Upgradeable(want).balanceOf(address(this));
        console.log("wantBal: ", wantBal);

        if (agEURBalance != 0 && cUSDBal != 0) {
            IERC20Upgradeable(CUSD).safeIncreaseAllowance(SPOOKY_ROUTER, cUSDBal);
            IERC20Upgradeable(AGEUR).safeIncreaseAllowance(SPOOKY_ROUTER, agEURBalance);
            IUniswapV2Router02(SPOOKY_ROUTER).addLiquidity(
                CUSD,
                AGEUR,
                cUSDBal,
                agEURBalance,
                0,
                0,
                address(this),
                block.timestamp
            );
        }
        wantBal = IERC20Upgradeable(want).balanceOf(address(this));
        console.log("wantBal: ", wantBal);
    }

    /**
     * @dev Function to calculate the total {want} held by the strat.
     *      It takes into account both the funds in hand, plus the funds in the MasterChef.
     */
    function balanceOf() public view override returns (uint256) {
        uint256 amount = ISteakHouseV2(MASTER_CHEF).getUserInfo(poolId, address(this)).amount;
        return amount + IERC20Upgradeable(want).balanceOf(address(this));
    }

    /**
     * @dev Returns the approx amount of profit from harvesting.
     *      Profit is denominated in WFTM, and takes fees into account.
     */
    function estimateHarvest() external view override returns (uint256 profit, uint256 callFeeToUser) {
        // uint256 pendingReward = IMasterChef(TSHARE_REWARDS_POOL).pendingShare(poolId, address(this));
        // uint256 totalRewards = pendingReward + IERC20Upgradeable(TSHARE).balanceOf(address(this));
        // if (totalRewards != 0) {
        //     profit += IUniswapV2Router02(SPOOKY_ROUTER).getAmountsOut(totalRewards, tshareToWftmPath)[1];
        // }
        // profit += IERC20Upgradeable(WFTM).balanceOf(address(this));
        // uint256 wftmFee = (profit * totalFee) / PERCENT_DIVISOR;
        // callFeeToUser = (wftmFee * callFee) / PERCENT_DIVISOR;
        // profit -= wftmFee;
    }

    /**
     * @dev Function to retire the strategy. Claims all rewards and withdraws
     *      all principal from external contracts, and sends everything back to
     *      the vault. Can only be called by strategist or owner.
     *
     * Note: this is not an emergency withdraw function. For that, see panic().
     */
    function _retireStrat() internal override {
        // IMasterChef(TSHARE_REWARDS_POOL).deposit(poolId, 0); // deposit 0 to claim rewards
        // uint256 tshareBal = IERC20Upgradeable(TSHARE).balanceOf(address(this));
        // _swap(tshareBal, tshareToWftmPath, SPOOKY_ROUTER);
        // uint256 wftmBal = IERC20Upgradeable(WFTM).balanceOf(address(this));
        // _swap(wftmBal, wftmToTombPath, SPOOKY_ROUTER);
        // uint256 tombHalf = IERC20Upgradeable(lpToken0).balanceOf(address(this)) / 2;
        // _swap(tombHalf, tombToMaiPath, TOMB_ROUTER);
        // _addLiquidity();
        // (uint256 poolBal, ) = IMasterChef(TSHARE_REWARDS_POOL).userInfo(poolId, address(this));
        // IMasterChef(TSHARE_REWARDS_POOL).withdraw(poolId, poolBal);
        // uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this));
        // IERC20Upgradeable(want).safeTransfer(vault, wantBalance);
    }

    /**
     * Withdraws all funds leaving rewards behind.
     */
    function _reclaimWant() internal override {
        // IMasterChef(TSHARE_REWARDS_POOL).emergencyWithdraw(poolId);
    }
}
