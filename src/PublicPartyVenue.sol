// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {PartyErrors} from "./types/PartyErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Factory} from "./interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {IWETH} from "./interfaces/IWETH.sol";
// import {TickMath} from "./libraries/TickMath.sol";
import {UniswapV3ERC20} from "./tokens/UniswapV3ERC20.sol";

contract PublicPartyVenue is Owned, ReentrancyGuard {
    using PartyErrors for *;

    // fee to account for gas costs when distributing tokens
    uint256 public constant DISTRO_FEE = 0.0001 ether;

    address public immutable partyStarter;
    address public immutable vault;

    uint256 public immutable timeout;
    uint256 public immutable ethAmount;
    uint256 public immutable tokenAmount;
    uint256 public immutable maxEthContribution;

    string public name = "";
    string public symbol = "";
    string public metadata = "";
    string public image = "";
    string public website = "";
    string public twitter = "";
    string public telegram = "";

    uint256 public totalContributions = 0;

    bool public launched = false;
    bool public refundable = false;
    bool public nameSet = false;
    bool public symbolSet = false;
    bool public metadataSet = false;
    bool public imageSet = false;
    bool public websiteSet = false;
    bool public twitterSet = false;
    bool public telegramSet = false;

    IUniswapV3Factory public immutable factory;
    INonfungiblePositionManager public immutable positionManager;
    IWETH public immutable weth;
    uint24 public immutable poolFee = 10000;
    IERC20 public token;

    mapping(address => uint256) public contributions;
    mapping(address => bool) public refunded;
    mapping(address => bool) public claimed;
    address[] public contributors;

    event Contribution(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Refundable();
    event Claimed(address indexed contributor, uint256 amount);
    event PartyLaunched(
        address indexed partyStarter,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    event MetadataSet(
        string name,
        string symbol,
        string metadata,
        string image,
        string website,
        string twitter,
        string telegram
    );

    constructor(
        address _partyStarter,
        address _vault,
        uint256 _timeout,
        uint256 _ethAmount,
        uint256 _tokenAmount,
        uint256 _maxEthContribution,
        address _factory,
        address _positionManager
    ) Owned(msg.sender) {
        partyStarter = _partyStarter;
        vault = _vault;
        timeout = _timeout;
        ethAmount = _ethAmount;
        tokenAmount = _tokenAmount;
        maxEthContribution = _maxEthContribution;
        factory = IUniswapV3Factory(_factory);
        positionManager = INonfungiblePositionManager(_positionManager);
        weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    }

    // LAUNCH - anyone can start the party after the timeout.
    // only the party starter can start the party before the timeout.

    function launch() external nonReentrant {
        PartyErrors.requireValidState(
            !launched,
            PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
        );

        PartyErrors.requireValidState(
            block.timestamp >= timeout || msg.sender == partyStarter,
            PartyErrors.ErrorCode.INVALID_LAUNCH_TIME
        );

        // 1. Create Token
        token = new UniswapV3ERC20(name, symbol, tokenAmount);

        // 2. Wrap ETH
        weth.deposit{value: address(this).balance}();

        // 3. Create Pool and add liquidity
        uint256 wethBalance = weth.balanceOf(address(this));
        PartyErrors.requireValidState(
            wethBalance > 0,
            PartyErrors.ErrorCode.ZERO_AMOUNT
        );

        address token0 = address(weth) < address(token)
            ? address(weth)
            : address(token);
        address token1 = address(weth) < address(token)
            ? address(token)
            : address(weth);

        uint160 sqrtPriceX96 = 79228162514264337593543950336; // 1:1 price for new pools

        positionManager.createAndInitializePoolIfNecessary(
            token0,
            token1,
            poolFee,
            sqrtPriceX96
        );

        token.approve(address(positionManager), type(uint256).max);
        weth.approve(address(positionManager), type(uint256).max);

        uint256 lpTokenAmount = tokenAmount / 2;

        positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: poolFee,
                tickLower: -887272,
                tickUpper: 887272,
                amount0Desired: token0 == address(weth)
                    ? wethBalance
                    : lpTokenAmount,
                amount1Desired: token1 == address(token)
                    ? lpTokenAmount
                    : wethBalance,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        launched = true;
    }

    // REFUND - anyone can set the refundable flag to true after the timeout. This
    // can only happen if metadata was not uploaded.

    function setRefundable() external onlyOwner {
        PartyErrors.requireValidState(
            block.timestamp >= timeout,
            PartyErrors.ErrorCode.LAUNCH_TIME_NOT_REACHED
        );

        // if the party was launched, it is not refundable
        PartyErrors.requireValidState(
            !launched,
            PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
        );

        // if metadata was uploaded, the party is not refundable
        PartyErrors.requireValidState(
            bytes(name).length == 0 &&
                bytes(symbol).length == 0 &&
                bytes(metadata).length == 0,
            PartyErrors.ErrorCode.NOT_REFUNDABLE
        );

        // if the party is already refundable, it cannot be set to false
        PartyErrors.requireValidState(
            !refundable,
            PartyErrors.ErrorCode.ALREADY_REFUNDABLE
        );

        emit Refundable();
        refundable = true;
    }

    function refund() external nonReentrant {
        PartyErrors.requireValidState(
            refundable,
            PartyErrors.ErrorCode.NOT_REFUNDABLE
        );

        PartyErrors.requireValidState(
            contributions[msg.sender] > 0,
            PartyErrors.ErrorCode.NO_FUNDS_RECEIVED
        );

        PartyErrors.requireValidState(
            !refunded[msg.sender],
            PartyErrors.ErrorCode.ALREADY_REFUNDED
        );

        uint256 refundAmount = contributions[msg.sender];

        payable(msg.sender).transfer(refundAmount);

        refunded[msg.sender] = true;
        emit Refunded(msg.sender, refundAmount);
    }

    function claim() external nonReentrant {
        PartyErrors.requireValidState(
            launched,
            PartyErrors.ErrorCode.PARTY_NOT_LAUNCHED
        );
        PartyErrors.requireValidState(
            !claimed[msg.sender],
            PartyErrors.ErrorCode.ALREADY_CLAIMED
        );
        PartyErrors.requireValidState(
            contributions[msg.sender] > 0,
            PartyErrors.ErrorCode.NO_FUNDS_RECEIVED
        );

        uint256 tokensForDistribution = token.balanceOf(address(this));
        uint256 userTokenAmount = (contributions[msg.sender] *
            tokensForDistribution) / totalContributions;

        claimed[msg.sender] = true;
        token.transfer(msg.sender, userTokenAmount);

        emit Claimed(msg.sender, userTokenAmount);
    }

    // CONTRIBUTION
    function contribute() external payable nonReentrant {
        PartyErrors.requireValidState(
            !launched,
            PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
        );
        PartyErrors.requireNonZero(
            msg.value,
            PartyErrors.ErrorCode.ZERO_AMOUNT
        );

        _processContribution();
    }

    function _processContribution() internal {
        // Check if this is a new contributor
        if (contributions[msg.sender] == 0) {
            contributors.push(msg.sender);
        }

        uint256 availableContribution = ethAmount - totalContributions;
        PartyErrors.requireValidState(
            availableContribution > 0,
            PartyErrors.ErrorCode.CONTRIBUTION_TOO_HIGH // Party is full
        );

        uint256 contributionAmount = msg.value;
        uint256 refund = 0;

        if (contributionAmount > availableContribution) {
            refund = contributionAmount - availableContribution;
            contributionAmount = availableContribution;
        }

        PartyErrors.requireValidState(
            contributions[msg.sender] + contributionAmount <=
                maxEthContribution,
            PartyErrors.ErrorCode.CONTRIBUTION_TOO_HIGH
        );

        totalContributions += contributionAmount;
        contributions[msg.sender] += contributionAmount;

        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        emit Contribution(msg.sender, contributionAmount);
    }

    // SETTERS FOR METADATA
    function setBatchMetadata(
        string memory _name,
        string memory _symbol,
        string memory _metadata,
        string memory _image,
        string memory _website,
        string memory _twitter,
        string memory _telegram
    ) external onlyPartyStarter {
        // Only set fields that are provided (non-empty) and not already set
        if (bytes(_name).length > 0) {
            PartyErrors.requireValidState(
                !nameSet,
                PartyErrors.ErrorCode.METADATA_ALREADY_SET
            );
            name = _name;
            nameSet = true;
        }

        if (bytes(_symbol).length > 0) {
            PartyErrors.requireValidState(
                !symbolSet,
                PartyErrors.ErrorCode.METADATA_ALREADY_SET
            );
            symbol = _symbol;
            symbolSet = true;
        }

        if (bytes(_metadata).length > 0) {
            PartyErrors.requireValidState(
                !metadataSet,
                PartyErrors.ErrorCode.METADATA_ALREADY_SET
            );
            metadata = _metadata;
            metadataSet = true;
        }

        if (bytes(_image).length > 0) {
            PartyErrors.requireValidState(
                !imageSet,
                PartyErrors.ErrorCode.METADATA_ALREADY_SET
            );
            image = _image;
            imageSet = true;
        }

        if (bytes(_website).length > 0) {
            PartyErrors.requireValidState(
                !websiteSet,
                PartyErrors.ErrorCode.METADATA_ALREADY_SET
            );
            website = _website;
            websiteSet = true;
        }

        if (bytes(_twitter).length > 0) {
            PartyErrors.requireValidState(
                !twitterSet,
                PartyErrors.ErrorCode.METADATA_ALREADY_SET
            );
            twitter = _twitter;
            twitterSet = true;
        }

        if (bytes(_telegram).length > 0) {
            PartyErrors.requireValidState(
                !telegramSet,
                PartyErrors.ErrorCode.METADATA_ALREADY_SET
            );
            telegram = _telegram;
            telegramSet = true;
        }

        emit MetadataSet(
            _name,
            _symbol,
            _metadata,
            _image,
            _website,
            _twitter,
            _telegram
        );
    }

    function setName(string memory _name) external onlyPartyStarter {
        PartyErrors.requireValidState(
            !nameSet,
            PartyErrors.ErrorCode.METADATA_ALREADY_SET
        );
        name = _name;
        nameSet = true;
    }

    function setSymbol(string memory _symbol) external onlyPartyStarter {
        PartyErrors.requireValidState(
            !symbolSet,
            PartyErrors.ErrorCode.METADATA_ALREADY_SET
        );
        symbol = _symbol;
        symbolSet = true;
    }

    function setMetadata(string memory _metadata) external onlyPartyStarter {
        PartyErrors.requireValidState(
            !metadataSet,
            PartyErrors.ErrorCode.METADATA_ALREADY_SET
        );
        metadata = _metadata;
        metadataSet = true;
    }

    function setImage(string memory _image) external onlyPartyStarter {
        PartyErrors.requireValidState(
            !imageSet,
            PartyErrors.ErrorCode.METADATA_ALREADY_SET
        );
        image = _image;
        imageSet = true;
    }

    function setWebsite(string memory _website) external onlyPartyStarter {
        PartyErrors.requireValidState(
            !websiteSet,
            PartyErrors.ErrorCode.METADATA_ALREADY_SET
        );
        website = _website;
        websiteSet = true;
    }

    function setTwitter(string memory _twitter) external onlyPartyStarter {
        PartyErrors.requireValidState(
            !twitterSet,
            PartyErrors.ErrorCode.METADATA_ALREADY_SET
        );
        twitter = _twitter;
        twitterSet = true;
    }

    function setTelegram(string memory _telegram) external onlyPartyStarter {
        PartyErrors.requireValidState(
            !telegramSet,
            PartyErrors.ErrorCode.METADATA_ALREADY_SET
        );
        telegram = _telegram;
        telegramSet = true;
    }

    modifier onlyPartyStarter() {
        PartyErrors.requireAuthorized(
            msg.sender == partyStarter,
            PartyErrors.ErrorCode.ONLY_PARTY_STARTER
        );
        _;
    }
}
