import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("SimpleStorage", function () {
  async function deploy() {
    const storage = 1n;

    const SimpleStorage = await hre.ethers.getContractFactory("SimpleStorage");
    const simpleStorage = SimpleStorage.deploy();

    return { simpleStorage, storage };
  }

  describe("set", function () {
    it("Should input number > 0", async function () {
      const { simpleStorage } = await loadFixture(deploy);
      await expect((await simpleStorage).set(0)).to.be.revertedWith(
        "must be > 0"
      );
    });

    it("Set Storage", async function () {
      const { simpleStorage, storage } = await loadFixture(deploy);
      expect((await simpleStorage).set(storage)).not.to.be.reverted;
    });
  });

  describe("get", function () {
    it("Should is Storage", async function () {
      const { simpleStorage, storage } = await loadFixture(deploy);
      await (await simpleStorage).set(storage);
      await expect(await (await simpleStorage).get()).to.equal(storage);
    });
  });
});
