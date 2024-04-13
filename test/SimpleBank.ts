import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("SimpleBank", function () {
  async function deploy() {
    const [owner, otherAccount] = await hre.ethers.getSigners();
    const eth = "1";
    const SimpleBank = await hre.ethers.getContractFactory("SimpleBank");
    const simpleBank = await SimpleBank.deploy();
    const contractAddress = await simpleBank.getAddress();

    return { simpleBank, eth, owner, contractAddress };
  }

  describe("deposit", function () {
    it("Should deposit gt 0", async function () {
      const { simpleBank, eth, owner } = await loadFixture(deploy);
      const depositTx = simpleBank.connect(owner).deposit({ value: 0 });

      await expect(depositTx).to.be.revertedWith("Please deposit some money");
    });

    it("Should can deposit money", async function () {
      const { simpleBank, eth, owner } = await loadFixture(deploy);
      const depositAmount = hre.ethers.parseEther(eth);

      await expect(simpleBank.connect(owner).deposit({ value: depositAmount }))
        .not.to.reverted;
    });
  });

  describe("withdraw", function () {
    describe("Validations", async function () {
      it("Should wirhdraw gt 0", async function () {
        const { simpleBank } = await loadFixture(deploy);

        await expect(simpleBank.withdraw(0)).to.be.revertedWith(
          "Withdrawal amount must be greater than zero"
        );
      });

      it("Withdraw Should less than balance", async function () {
        const { simpleBank, contractAddress } = await loadFixture(deploy);

        const balance = await hre.ethers.provider.getBalance(contractAddress);

        await expect(simpleBank.withdraw(balance + 1n)).to.be.revertedWith(
          "Not enough money"
        );
      });

      it("Shouldn't fail if balance is enough", async function () {
        const { simpleBank, eth, owner, contractAddress } = await loadFixture(
          deploy
        );

        let balance = await hre.ethers.provider.getBalance(contractAddress);

        if (balance === 0n) {
          const depositAmount = hre.ethers.parseEther(eth);
          const txDeposit = simpleBank
            .connect(owner)
            .deposit({ value: depositAmount });
          (await txDeposit).wait();
          balance = await hre.ethers.provider.getBalance(contractAddress);
        }

        await expect(simpleBank.connect(owner).withdraw(balance + 1n)).to.be
          .reverted;
      });
    });

    describe("Events", async function () {
      it("Should emit an event on withdrawals", async function () {
        const { simpleBank, eth, owner, contractAddress } = await loadFixture(
          deploy
        );

        const depositAmount = hre.ethers.parseEther(eth);
        const txDeposit = simpleBank
          .connect(owner)
          .deposit({ value: depositAmount });
        (await txDeposit).wait();

        await expect(simpleBank.connect(owner).withdraw(1n))
          .to.emit(simpleBank, "Withdraw")
          .withArgs(1n);
      });
    });

    describe("Transfers", async function () {
      it("Should transfer the funds to the owner", async function () {
        const { simpleBank, eth, owner, contractAddress } = await loadFixture(
          deploy
        );
        const depositAmount = hre.ethers.parseEther(eth);
        const txDeposit = simpleBank
          .connect(owner)
          .deposit({ value: depositAmount });
        (await txDeposit).wait();

        await expect(
          simpleBank.connect(owner).withdraw(1n)
        ).to.changeEtherBalances([contractAddress, owner], [-1n, 1n]);
      });
    });
  });

  describe("deposit money equal balance", function () {
    it("getBalance", async function () {
      const { simpleBank, eth, owner } = await loadFixture(deploy);
      const depositAmount = hre.ethers.parseEther(eth);
      const txDeposit = simpleBank
        .connect(owner)
        .deposit({ value: depositAmount });
      (await txDeposit).wait();

      await expect(await simpleBank.getBalance()).to.equal(depositAmount);
    });
  });
});
