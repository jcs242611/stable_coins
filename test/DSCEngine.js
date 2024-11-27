const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Stable Coins", function () {
  let owner, user1, user2;
  let ERC20Mock;
  let collateralToken, priceFeed, stableCoin, dscEngine;

  const INITIAL_SUPPLY = ethers.parseUnits("1000", 18);
  const COLLATERAL_AMOUNT = ethers.parseUnits("100", 18);
  const STABLECOIN_AMOUNT = ethers.parseUnits("50", 18);

  beforeEach(async () => {
    ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    collateralToken = await ERC20Mock.deploy(
      "MockCollateralToken",
      "MCT",
      INITIAL_SUPPLY
    );

    const MockAggregator = await ethers.getContractFactory("MockAggregator");
    priceFeed = await MockAggregator.deploy(ethers.parseUnits("1", 8), 8);

    const StableCoin = await ethers.getContractFactory(
      "DecentralizedStableCoin"
    );
    stableCoin = await StableCoin.deploy();

    const DSCEngine = await ethers.getContractFactory("DSCEngine");
    dscEngine = await DSCEngine.deploy(
      stableCoin.getAddress(),
      [collateralToken.getAddress()],
      [priceFeed.getAddress()]
    );

    const accounts = await ethers.getSigners();
    [owner, user1, user2] = accounts.slice(0, 3);

    await stableCoin.connect(owner).allowSingleSC(dscEngine.getAddress());
    await collateralToken.transfer(user1.address, COLLATERAL_AMOUNT);
  });

  describe("Deposit collateral and mint", function () {
    it("should allow a user to deposit collateral and mint stable coins", async () => {
      await collateralToken
        .connect(user1)
        .approve(dscEngine.getAddress(), COLLATERAL_AMOUNT);
      await dscEngine
        .connect(user1)
        .depositCollateralAndMint(
          collateralToken.getAddress(),
          COLLATERAL_AMOUNT,
          STABLECOIN_AMOUNT
        );

      const userCollateralBalance = await dscEngine.getCollateralBalanceOfUser(
        user1.address,
        collateralToken.getAddress()
      );
      const userAccountInfo = await dscEngine.getAccountInformation(
        user1.address
      );

      expect(userCollateralBalance).to.equal(COLLATERAL_AMOUNT);
      expect(userAccountInfo[1]).to.equal(STABLECOIN_AMOUNT);

      const stableCoinBalance = await stableCoin.balanceOf(user1.address);
      expect(stableCoinBalance).to.equal(STABLECOIN_AMOUNT);
    });

    it("should revert if the collateral token is not accepted", async function () {
      const unacceptedToken = await ERC20Mock.deploy(
        "UnacceptedToken",
        "UNAC",
        INITIAL_SUPPLY
      );
      await unacceptedToken.transfer(user1.address, COLLATERAL_AMOUNT);
      await unacceptedToken
        .connect(user1)
        .approve(dscEngine.getAddress(), COLLATERAL_AMOUNT);

      await expect(
        dscEngine
          .connect(user1)
          .depositCollateralAndMint(
            unacceptedToken.getAddress(),
            COLLATERAL_AMOUNT,
            STABLECOIN_AMOUNT
          )
      ).to.be.revertedWith("[ERROR] Invalid collateral token");
    });

    it("should revert if health factor is too low", async function () {
      await collateralToken
        .connect(user1)
        .approve(dscEngine.getAddress(), COLLATERAL_AMOUNT);

      const LOW_HEALTH_FACTOR_AMOUNT = ethers.parseUnits("200", 18);
      await expect(
        dscEngine
          .connect(user1)
          .depositCollateralAndMint(
            collateralToken.getAddress(),
            COLLATERAL_AMOUNT,
            LOW_HEALTH_FACTOR_AMOUNT
          )
      ).to.be.revertedWith("[WARNING] Health factor too low");
    });
  });

  describe("Redeem collateral for stable coin", function () {
    it("should allow a user to redeem collateral for stable coins", async function () {
      await collateralToken
        .connect(user1)
        .approve(dscEngine.getAddress(), COLLATERAL_AMOUNT);
      await dscEngine
        .connect(user1)
        .depositCollateralAndMint(
          collateralToken.getAddress(),
          COLLATERAL_AMOUNT,
          STABLECOIN_AMOUNT
        );

      const initialStableCoinBalance = await stableCoin.balanceOf(
        user1.address
      );
      const initialCollateralBalance = await collateralToken.balanceOf(
        user1.address
      );

      await dscEngine
        .connect(user1)
        .redeemCollateralForStableCoin(
          collateralToken.getAddress(),
          COLLATERAL_AMOUNT,
          STABLECOIN_AMOUNT
        );

      const finalStableCoinBalance = await stableCoin.balanceOf(user1.address);
      const finalCollateralBalance = await collateralToken.balanceOf(
        user1.address
      );

      expect(finalStableCoinBalance).to.equal(
        initialStableCoinBalance - STABLECOIN_AMOUNT
      );
      expect(finalCollateralBalance).to.equal(
        initialCollateralBalance + COLLATERAL_AMOUNT
      );
    });

    it("should revert if the user doesn't have enough collateral", async function () {
      await expect(
        dscEngine
          .connect(user1)
          .redeemCollateralForStableCoin(
            collateralToken.getAddress(),
            COLLATERAL_AMOUNT,
            STABLECOIN_AMOUNT
          )
      ).to.be.revertedWith("[ERROR] Insufficient collateral amount");
    });
  });

  describe("liquidate", function () {
    it("should allow liquidation if the health factor is too low", async function () {
      await collateralToken
        .connect(user1)
        .approve(dscEngine.getAddress(), COLLATERAL_AMOUNT);
      await dscEngine
        .connect(user1)
        .depositCollateralAndMint(
          collateralToken.getAddress(),
          COLLATERAL_AMOUNT,
          STABLECOIN_AMOUNT
        );

      priceFeed.setPrice(ethers.parseUnits("1", 4));

      await dscEngine.connect(user2).liquidate(user1.address);
    });

    it("should revert if the health factor is sufficient", async function () {
      await expect(
        dscEngine.connect(user2).liquidate(user1.address)
      ).to.be.revertedWith("[ERROR] Health factor sufficient");
    });
  });
});
