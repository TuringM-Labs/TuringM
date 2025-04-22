// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IERC20Burn {
    function burn(uint256 amount) external;
}

struct AppStorage {
    uint256 maxSlippageBps;
    uint256 maxFeeRateBps;
    uint256 minimumOrderSalt;
    mapping(address => bool) paymentAddressMap;
    mapping(uint256 => uint256[]) marketIdMap; // marketId => [nftId1, nftId2]
    mapping(uint256 => uint256) nftIdMapToMarketId;
    mapping(uint256 => mapping(address => uint256)) marketVaultMap; // marketId => (paymentTokenAddress => vaultAmount)
    mapping(uint256 => mapping(address => uint256)) marketWinnerPayAmountMap; // marketId => (paymentTokenAddress => payAmount)
    mapping(bytes32 => bool) orderIsFilledOrCancelledMap; // hash => true/false, true: filled or cancelled, false: default value
    mapping(bytes32 => uint256) orderRemainingMap; // hash => remaining amount
    mapping(address => bool) feeTokenAddressMap; // Configuration of allowed fee payment tokens
    mapping(address => uint256) feeTokenPriceUSDCMap; // Price denominated in USDC
    mapping(address => uint256) feeVaultAmountMap; // Total platform fee revenue (keyed by token address)
    mapping(address => uint256) feeVaultPayoutAmountMap; // Total platform fee expenditure (ensures no overpayment)
    mapping(address => bool) shouldBurnFeeTokenAddressMap;
    mapping(uint256 => uint256) marketWinNftIdMap; // marketId => winNftId
    mapping(uint256 => mapping(address => bool)) claimedUserMapByMarketId; // marketId => (userAddress => isClaimed)
    mapping(uint256 => bool) marketIsBlockedMap;
    mapping(uint256 => bool) marketIsEndedMap; // marketId => isEnded
    mapping(uint256 => bool) marketIsFinallizedMap; // marketId => isFinallized
    mapping(uint256 => bool) rewardClaimedNonceMap; // nonce => isClaimed
}

// payout: payCommissions && payDividends
bytes32 constant PERMISSION_PAYOUT = keccak256("PERMISSION_PAYOUT");

// market creator
bytes32 constant PERMISSION_CREATE_MARKET = keccak256("PERMISSION_CREATE_MARKET");
bytes32 constant PERMISSION_END_MARKET = keccak256("PERMISSION_END_MARKET");
bytes32 constant PERMISSION_CLAIM_REWARD = keccak256("PERMISSION_CLAIM_REWARD");
bytes32 constant PERMISSION_FINALIZE_MARKET = keccak256("PERMISSION_FINALIZE_MARKET");
bytes32 constant PERMISSION_BLOCK_MARKET = keccak256("PERMISSION_BLOCK_MARKET");
// order matcher
bytes32 constant PERMISSION_MATCH_ORDERS = keccak256("PERMISSION_MATCH_ORDERS");

uint256 constant MAX_ID = 2 ** 256 - 2;
uint256 constant TOKEN_DECIMALS = 6;

enum TradeType {
    mint, // taker buy A, maker1 buy A'
    mintSelf, // taker buy A and buy A'
    mintMixNormal, // taker buy 2 A, maker1 buy 1 A', maker2 sell 1 A
    normal, // taker buy/sell
    merge, // taker sell A, maker1 sell A'
    mergeSelf, // taker sell A and sell A'
    mergeMixNormal // taker sell 2 A, maker1 sell 1 A', maker2 buy 1 A
}

enum OrderSide {
    buy,
    sell
}

enum PayoutType{
    payCommissions,
    payDividends
}

bytes32 constant TYPEHASH_ORDER = keccak256(
    "Order(uint256 salt,address maker,uint256 tokenId,uint256 tokenAmount,uint256 tokenPriceInPaymentToken,address paymentTokenAddress,uint256 slippageBps,uint256 deadline,uint8 side,address feeTokenAddress)"
);

bytes32 constant TYPEHASH_PAYOUT = keccak256(
    "Payout(address to,address feeTokenAddress,uint256 amount,uint8 payoutType,uint256 nonce)"
);

bytes32 constant TYPEHASH_ORDER_SELF = keccak256(
    "OrderSelf(uint256 salt,address maker,uint256 marketId,uint256 tradeType,uint256 paymentTokenAmount,address paymentTokenAddress,uint256 deadline,address feeTokenAddress)"
);

bytes32 constant TYPEHASH_REWARD = keccak256(
    "Reward(uint256 marketId,uint256 nftId, address user,address paymentTokenAddress,uint256 nonce)"
);

struct Reward {
    uint256 marketId;
    uint256 nftId;
    address user;
    address paymentTokenAddress;
    uint256 nonce;
    bytes sig;
    // extra info for fee
    uint256 feeAmount;
}

struct Order {
    uint256 salt;
    address maker;
    uint256 tokenId;
    uint256 tokenAmount;
    uint256 tokenPriceInPaymentToken;
    address paymentTokenAddress;
    uint256 slippageBps;
    uint256 deadline;
    OrderSide side;
    address feeTokenAddress;
    bytes sig;
    // order extra info for exchange to calculate and validate
    uint256 exchangeNftAmount;
    uint256 paymentTokenAmount;
    uint256 fee1Amount;
    address fee1TokenAddress;
    uint256 fee2Amount;
    address fee2TokenAddress;
}
struct OrderSelf {
    uint256 salt;
    address maker;
    uint256 marketId; // Market ID
    uint256 tradeType; // mintSelf: 0 or mergeSelf: 1
    // Amount corresponding to merge/split orders
    // Example with 1 USDC:
    // Merge order: Burn 1 YES and 1 NO NFTs, disburse 1 USDC from market vault to maker
    // Split order: Deduct 1 USDC from user wallet to market vault, mint 1 YES and 1 NO NFTs to maker
    uint256 paymentTokenAmount;
    address paymentTokenAddress;
    uint256 deadline;
    address feeTokenAddress;
    bytes sig;
    uint256 fee1Amount;
    address fee1TokenAddress;
    uint256 fee2Amount;
    address fee2TokenAddress;
}

struct OrderMeta {
    address taker;
    uint256 marketId;
    uint256 takerNftId;
    TradeType tradeType;
    uint256 takerNftIdPair;
}

struct OrderResult {
    uint256 makerPaymentAmount; // Maker's payment amount (to exchange or taker)
    uint256 makerPayToMarketPaymentAmount; // Maker's payment to exchange vault
    uint256 marketPayToMakerPaymentAmount; // Exchange payment to maker (NFT burn amount only)
    uint256 mintTakerNftIdPair; // Minted takerNftIdPair NFT amount
    uint256 needTakerTransferToMakerNftAmount; // NFTs taker should transfer to maker
    uint256 needTakerTransferToMakerPaymentAmount; // USDC taker should transfer to maker
    uint256 needPayToTakerPaymentAmount; // USDC to disburse to taker
    uint256 needBurnTakerNftAmount; // Taker NFTs to burn
    // new
    // USDC
    // 给市场付费的
    uint256 payToMarketForNftId;
    uint256 payToMarketForNftIdPair;
    // 给 taker 付费的，不可能给 taker 付费 nftIdPair
    uint256 payToTakerForNftId;
    // NFT
    uint256 mintNftIdAmount;
    uint256 mintNftIdPairAmount;
    uint256 burnNftIdAmount;
    uint256 burnNftIdPairAmount;
    // 从 taker 拿的 NftId
    uint256 takeNftIdAmountFromTaker;
    // 给 taker 的 NftId
    uint256 giveTakerNftIdAmount;
}

struct FeeTokenInfo {
    uint256 vaultAmount;
    uint256 payoutAmount;
    bool isEnabled;
    uint256 priceUSDC;
    bool shouldBurn;
    uint256 decimals;
}

struct MarketInfo {
    uint256 marketId;
    uint256 nftId1;
    uint256 nftId2;
    uint256 vaultAmount;
    uint256 marketWinnerPayAmount;
    bool isEnded;
    bool isBlocked;
    bool isFinallized;
    uint256 winNftId;
}

error MarketAlreadyExists();
error MaxMarketReached();
error InvalidSignature(uint256 orderSalt, bytes sig, address orderMaker, address signer);
error OrderExpired(uint256 orderSalt, uint256 orderDeadline, uint256 currentTimestamp);
error MarketIsEndedOrBlocked(uint256 marketId, uint256 orderSalt);
error OrderFilledOrCancelled(uint256 salt);
error OrderRemainingNotEnough(uint256 orderSalt, uint256 nftAmount, uint256 orderRemaining);
error InvalidFeeToken(uint256 orderSalt, address feeTokenAddress);
error ChargeFeeFailed(uint256 orderSalt, address feeTokenAddress, uint256 feeAmount);
error PaymentTransferFailed(uint256 orderSalt, address from, address to, address paymentTokenAddress, uint256 paymentAmount);
error InvalidMarketIdForMaker(uint256 marketId, uint256 marketIdMaker, uint256 orderSalt);
error InvalidNftId(uint256 targetNftId, uint256 orderSalt, uint256 orderNftId);
error MarketIdNotExist(uint256 nftId, uint256 orderSalt);
error TakerPaymentNotValidate(uint256 orderSalt, uint256 takerShouldPayOrReceived, uint256 orderPaymentTokenAmount);
error TakerNFTReceivedNotValidate(uint256 orderSalt, uint256 takerShouldMint, uint256 takerMint);
error TakerNFTSendOutNotValidate(uint256 orderSalt, uint256 takerShouldSend, uint256 takerSend);
error MintNFTAmountNotEqual(uint256 orderSalt, uint256 nftAmount, uint256 nftPairAmount);
error InvalidUserWalletWithdrawNonce(address from, uint256 inputNonce, uint256 nonce);
error InvalidWithdrawSignature(address signer, address from, address to, uint256 amount, uint256 fee, address tokenAddress, uint256 nonce, bytes sig);
error TransferFailed(address tokenAddress, address from, address to, uint256 amount);
error InvalidPaymentToken(uint256 orderSalt, address paymentTokenAddress);
error InvalidOrderSide(uint256 orderSalt, OrderSide expectSide, OrderSide orderSide);
error InvalidSlippage(uint256 orderSalt, uint256 orderSlippage, uint256 maxSlippage);
error PaymentTokenAmountOverflow(
    uint8 flag,
    uint256 orderSalt,
    OrderSide orderSide,
    uint256 paymentTokenAmount,
    uint256 totalNeedPay,
    uint256 slippageBps
);
error MaxFeeExceeded(uint256 orderSalt, uint256 paymentAmount, uint256 totalFee, uint256 maxFeeRate);
error InvalidTradeType(uint256 orderSalt, OrderMeta orderMeta);
error InvalidBuyerPrice(OrderSide side, uint256 orderSalt, uint256 buyerPrice, uint256 sellerPrice);
error InvalidPrice(uint256 orderSalt, uint256 orderPrice);
error InvalidOrderSalt(uint256 orderSalt, uint256 minimumOrderSalt);
error NotWinningNft(uint256 marketId, uint256 nftId);
error RewardAlreadyClaimed(uint256 marketId, address user);
error NoNftOwned(uint256 nftId, address user);
error MarketNotFinallized(uint256 marketId);
error MarketAlreadyFinallized(uint256 marketId);
error MarketVaultNotEnoughForPayReward(
    uint256 marketId,
    uint256 marketVaultAmount,
    uint256 marketWinnerAlreadyPayAmount,
    address user,
    address paymentTokenAddress
);
error RewardTransferFailed(Reward reward,address paymentTokenAddress,uint256 amount,uint256 paymentTokenFeeAmount);
error MarketVaultBalanceInsufficient(uint256 available, uint256 required);
error NonceAlreadyUsed(uint256 nonce);
