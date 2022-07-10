// Types
import type { ContractsState } from "../interfaces";

// Libraries
import fs from "fs";
import yaml from "js-yaml";

/** Output the details into a yaml file */
export default async (state: ContractsState): Promise<ContractsState> => {
    if (!state.baseFund) return state;
    if (!state.tokens) return state;

    console.log("--- bsc > output > start ---");

    const tokens: Record<string, string[]> = state.tokens.reduce(
        (current, each, index) => ({
            ...current,
            [index === 0 ? "WBNB" : `TKN${index}`]: [each.token.address, each.chainlinkOracle.address],
        }),
        {}
    );
    const reversedTokensW: Record<string, string> = state.tokens.reduce(
        (current, each, index) => ({ ...current, [each.token.address]: index === 0 ? "WBNB" : `TKN${index}` }),
        {}
    );
    const reversedTokens: Record<string, string> = state.tokens.reduce(
        (current, each, index) => ({ ...current, [each.token.address]: index === 0 ? "BNB" : `TKN${index}` }),
        {}
    );

    // Use underscore-casing for python side's usage
    const output = {
        tokens: Object.entries(tokens).reduce(
            (current, [symbol, [address]]) => ({
                ...current,
                [symbol]: { address, decimals: 18 },
            }),
            {}
        ),
        protocols: {
            pancakeswap: {
                cake_token: state.protocols?.pancakeswap?.cakeToken.address,
                master_chef_v2: state.protocols?.pancakeswap?.masterChefV2.address,
                cake_pool: state.protocols?.pancakeswap?.cakePool.address,
                smart_chefs: state.protocols?.pancakeswap?.pools.reduce(
                    (current, each) => ({
                        ...current,
                        [`CAKE-${reversedTokensW[each.underlying.address]}`]: each.pool.address,
                    }),
                    {}
                ),
                router: state.protocols?.pancakeswap?.router.address,
                pairs: state.protocols?.pancakeswap?.pairs.reduce(
                    (current, each) => ({
                        ...current,
                        [`${reversedTokensW[each.underlyingA.address]}-${reversedTokensW[each.underlyingB.address]}`]: {
                            address: each.pair.address,
                            pid: state.protocols?.pancakeswap?.pidsMapper[each.pair.address],
                        },
                    }),
                    {}
                ),
            },
            venus: {
                unitroller: state.protocols?.venus?.comptrollerG5.address,
                xvs: state.protocols?.venus?.xvs.address,
                lens: state.protocols?.venus?.lens.address,
                pools: state.protocols?.venus?.lendingPools.reduce(
                    (current, each) => ({
                        ...current,
                        [reversedTokens[each.underlying.address]]: each.pool.address,
                    }),
                    {}
                ),
            },
        },
        fund: {
            address: state.baseFund.fund.address,
            ops_governor: state.baseFund.opsGovernor.address,
            utils: {
                pancakeswap_lp_farming_util: state.baseFund.utils.pancakeswapLpFarmingUtil.address,
            },
        },
        multicall: state.multicall?.address,
    };

    // Write json file
    fs.writeFileSync("bsc-config-local.json", JSON.stringify(output, null, 2));

    // Write yaml file
    fs.writeFileSync("bsc-config-local.yaml", yaml.dump(output));

    console.log("--- bsc > output > done ---");

    return state;
};
