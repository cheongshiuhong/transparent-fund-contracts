// Types
import type { Contract } from "ethers";
import type { ContractsState, PancakeswapProtocols } from "../../interfaces";

// Libraries
import { ethers } from "hardhat";

// Code
import helpers from "../../helpers";

/** Setup pancakeswap"s contracts and liquidity pools */
export default async (state: ContractsState): Promise<ContractsState> => {
    if (!state.tokens) return state;

    console.log("--- bsc > setup > protocols > pancakeswap > start ---");

    // Cake Token
    const ERC20 = await ethers.getContractFactory("MockedERC20");
    const cakeToken = await ERC20.deploy("Pancakeswap Cake Token", "CAKE");
    await cakeToken.deployed();

    // Create a pancake profile
    const PancakeProfile = await ethers.getContractFactory("PancakeProfile");
    const pancakeProfile = await PancakeProfile.deploy(
        cakeToken.address,
        0, // number cake to reactivate
        0, // number cake to register
        0 // number cake to update
    );
    await pancakeProfile.deployed();
    await (await pancakeProfile.addTeam("Pancakeswap", "Pancakeswap's Team")).wait();

    // Syrup Bar
    const SyrupBar = await ethers.getContractFactory("SyrupBar");
    const syrupBar = await SyrupBar.deploy(cakeToken.address);
    await syrupBar.deployed();

    // Master Chef (devAddress is signer 0)
    const MasterChef = await ethers.getContractFactory("MasterChef");
    const masterChef = await MasterChef.deploy(
        cakeToken.address,
        syrupBar.address,
        state.signers[0].address,
        100, // Cakes per block
        1
    );
    await masterChef.deployed();

    // MasterChefV2
    const MasterChefV2 = await ethers.getContractFactory("MasterChefV2");
    const masterChefV2 = await MasterChefV2.deploy(masterChef.address, cakeToken.address, 1, state.signers[0].address);
    await masterChefV2.deployed();

    // Mint loads of CAKE to MasterChefV2 so it won't touch V1
    cakeToken.mint(masterChefV2.address, ethers.utils.parseEther("10000"));

    // Mint loads of CAKE to the signers
    await Promise.all(state.signers.map((signer) => cakeToken.mint(signer.address, ethers.utils.parseEther("10000"))));

    // Init dummy tokens to takeover pid = 0 and 1
    const dummyToken0 = await ERC20.deploy("Dummy Token 0", "DUMMY0");
    await dummyToken0.deployed();
    const dummyToken1 = await ERC20.deploy("Dummy Token 1", "DUMMY1");
    await dummyToken1.deployed();
    await (await masterChefV2.add(1, dummyToken0.address, true, true)).wait();
    await (await masterChefV2.add(1, dummyToken1.address, true, true)).wait();

    // CakePool
    const CakePool = await ethers.getContractFactory("CakePool");
    const cakePool = await CakePool.deploy(
        cakeToken.address,
        masterChefV2.address,
        state.signers[0].address, // admin
        masterChefV2.address, // treasury
        state.signers[0].address, // operator
        0 // PID for CAKE is 0
    );

    // Smart Chef Factory
    const SmartChefFactory = await ethers.getContractFactory("SmartChefFactory");
    const smartChefFactory = await SmartChefFactory.deploy();

    // Other Pools
    const currentBlock = await helpers.getBlock();
    await Promise.all(
        state.tokens.map((each) =>
            smartChefFactory.deployPool(
                cakeToken.address, // staked token
                each.token.address, // reward token
                100, // reward per block
                currentBlock, // start block
                currentBlock + 10000, // bonus end block
                0, // pool limit per user
                0, // number of blocks for user limit
                pancakeProfile.address, // pancake profile
                false, // pancake profile is requested
                0, // pancake profile threshold points
                state.signers[0].address // admin
            )
        )
    );

    const SmartChef = await ethers.getContractFactory("SmartChefInitializable");
    const poolAddresses: string[] = await smartChefFactory.getSmartChefs();

    const pools: PancakeswapProtocols["pools"] = [];
    for (let i = 0; i < poolAddresses.length; i++) {
        pools.push({
            pool: SmartChef.attach(poolAddresses[i]),
            underlying: state.tokens[i].token,
        });
    }

    // Pair Factory (_feeToSetter is signer 0)
    const PairFactory = await ethers.getContractFactory("PancakeFactory");
    const pairFactory = await PairFactory.deploy(state.signers[0].address);
    await pairFactory.deployed();

    // Router
    const PancakeRouter = await ethers.getContractFactory("PancakeRouter");
    const router = await PancakeRouter.deploy(pairFactory.address, state.tokens[0].token.address);
    await router.deployed();

    // Create pairs and add liquidity
    const PancakePair = await ethers.getContractFactory("PancakePair");
    const pairs: PancakeswapProtocols["pairs"] = [];
    const pidsMapper: PancakeswapProtocols["pidsMapper"] = {};
    const amount = ethers.utils.parseEther("100"); // 100 ethers

    for (let i = 0; i < state.tokens.length; i++) {
        const underlyingA: Contract = state.tokens[i].token;

        for (let j = i + 1; j < state.tokens.length; j++) {
            const underlyingB: Contract = state.tokens[j].token;

            // Create pair
            await (await pairFactory.createPair(underlyingA.address, underlyingB.address)).wait();
            const pairAddress = await pairFactory.getPair(underlyingA.address, underlyingB.address);
            pairs.push({ underlyingA, underlyingB, pair: PancakePair.attach(pairAddress) });

            // Create farm with the masterchef
            await (await masterChefV2.add(1, pairAddress, true, true)).wait();
            pidsMapper[pairAddress] = pairs.length + 1; // Starts at 2 (0 is for CAKE, 1 is for V2 Dummy Pool)

            // Give allowance
            await (await underlyingA.connect(state.signers[0]).approve(router.address, amount)).wait();
            await (await underlyingB.connect(state.signers[0]).approve(router.address, amount)).wait();

            // Add liquidity
            await (
                await router
                    .connect(state.signers[0])
                    .addLiquidity(
                        state.tokens[i].token.address,
                        state.tokens[j].token.address,
                        amount,
                        amount,
                        amount,
                        amount,
                        state.signers[0].address,
                        await helpers.getBlockTimestampWithDelay(100)
                    )
            ).wait();
        }
    }

    console.log("--- bsc > setup > protocols > pancakeswap > done ---");

    return {
        ...state,
        protocols: {
            ...(state.protocols || {}),
            pancakeswap: {
                cakeToken,
                syrupBar,
                masterChef,
                masterChefV2,
                // Single-token pools
                cakePool,
                smartChefFactory,
                pools,
                // Swaps & Liquidities
                pairFactory,
                router,
                pairs,
                // Off-chain reference
                pidsMapper,
            },
        },
    };
};
